
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs/promises');
const path = require('path');
const multer = require('multer');
require('dotenv').config();

const { getConnection } = require('./database');
const oracledb = require('oracledb');
const { getLocationAnomalies } = require('./location_anomaly');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// ========================================
// PENYIMPANAN SEMENTARA
// ========================================

// Token login: token -> data user
const activeSessions = new Map();

// Lokasi agen aktif: ID agen -> data lokasi
const activeAgents = new Map();

// Lokasi terakhir agen, termasuk agen yang sudah berhenti tracking
const lastKnownAgents = new Map();

function stopAgentTracking(stambuk) {
    const agent = activeAgents.get(stambuk);
    if (!agent) return lastKnownAgents.get(stambuk) ?? null;

    const offlineAgent = {
        ...agent,
        status: 'offline',
        isTracking: false,
        stoppedAt: new Date().toISOString(),
    };
    activeAgents.delete(stambuk);
    lastKnownAgents.set(stambuk, offlineAgent);
    return offlineAgent;
}

// ========================================
// PENYIMPANAN TUGAS AGEN (JSON)
// ========================================

const TASKS_DIR = path.join(__dirname, 'data');
const TASKS_FILE = path.join(TASKS_DIR, 'tugas.json');
const PROFILE_PHOTO_DIR = process.env.PROFILE_PHOTO_DIR ||
    path.join(__dirname, 'uploads', 'profile-photos');
const PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024;
const profilePhotoUpload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: PROFILE_PHOTO_MAX_BYTES,
        files: 1,
        fields: 0,
        parts: 1,
    },
});
const profileUpdateUpload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: PROFILE_PHOTO_MAX_BYTES,
        files: 1,
        fields: 1,
        parts: 2,
    },
});

function getProfilePhotoMetadataPath(agentId) {
    const agentKey = crypto
        .createHash('sha256')
        .update(String(agentId))
        .digest('hex');
    return path.join(PROFILE_PHOTO_DIR, `${agentKey}.json`);
}

function getProfilePhotoType(buffer) {
    if (
        buffer.length >= 3 &&
        buffer[0] === 0xff &&
        buffer[1] === 0xd8 &&
        buffer[2] === 0xff
    ) {
        return { extension: '.jpg', mimeType: 'image/jpeg' };
    }

    if (
        buffer.length >= 8 &&
        buffer.subarray(0, 8).equals(
            Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        )
    ) {
        return { extension: '.png', mimeType: 'image/png' };
    }

    if (
        buffer.length >= 12 &&
        buffer.toString('ascii', 0, 4) === 'RIFF' &&
        buffer.toString('ascii', 8, 12) === 'WEBP'
    ) {
        return { extension: '.webp', mimeType: 'image/webp' };
    }

    return null;
}

async function readProfilePhotoMetadata(agentId) {
    try {
        const content = await fs.readFile(
            getProfilePhotoMetadataPath(agentId),
            'utf8'
        );
        const metadata = JSON.parse(content);
        if (
            typeof metadata.filename !== 'string' ||
            path.basename(metadata.filename) !== metadata.filename ||
            !/^[0-9a-f-]+\.(jpg|png|webp)$/.test(metadata.filename) ||
            !['image/jpeg', 'image/png', 'image/webp'].includes(metadata.mimeType)
        ) {
            throw new Error('Metadata foto profil tidak valid.');
        }
        return metadata;
    } catch (error) {
        if (error.code === 'ENOENT') return null;
        throw error;
    }
}

async function applyProfilePhotoChange({
    agentId,
    photoFile,
    photoType,
    removePhoto,
}) {
    const metadataPath = getProfilePhotoMetadataPath(agentId);
    const previousMetadata = await readProfilePhotoMetadata(agentId);
    const previousPhotoPath = previousMetadata
        ? path.join(PROFILE_PHOTO_DIR, previousMetadata.filename)
        : null;
    let previousPhotoBytes = null;
    if (previousPhotoPath) {
        try {
            previousPhotoBytes = await fs.readFile(previousPhotoPath);
        } catch (error) {
            if (error.code !== 'ENOENT') throw error;
        }
    }

    const change = {
        metadataPath,
        previousMetadata,
        previousPhotoPath,
        previousPhotoBytes,
        newPhotoPath: null,
        temporaryMetadataPath: null,
        metadataChanged: false,
        previousPhotoRemoved: false,
    };

    try {
        await fs.mkdir(PROFILE_PHOTO_DIR, { recursive: true });

        if (photoFile) {
            const filename = `${crypto.randomUUID()}${photoType.extension}`;
            change.newPhotoPath = path.join(PROFILE_PHOTO_DIR, filename);
            change.temporaryMetadataPath =
                `${metadataPath}.${crypto.randomUUID()}.tmp`;

            await fs.writeFile(change.newPhotoPath, photoFile.buffer, {
                flag: 'wx',
            });
            await fs.writeFile(
                change.temporaryMetadataPath,
                JSON.stringify({
                    filename,
                    mimeType: photoType.mimeType,
                    updatedAt: new Date().toISOString(),
                }),
                { flag: 'wx' }
            );
            await fs.rename(change.temporaryMetadataPath, metadataPath);
            change.temporaryMetadataPath = null;
            change.metadataChanged = true;
        } else if (removePhoto) {
            await fs.unlink(metadataPath).catch(error => {
                if (error.code !== 'ENOENT') throw error;
            });
            change.metadataChanged = true;
        }

        if (
            previousPhotoPath &&
            (removePhoto || photoFile) &&
            (!photoFile ||
                path.basename(change.newPhotoPath) !==
                    previousMetadata.filename)
        ) {
            await fs.unlink(previousPhotoPath).catch(error => {
                if (error.code !== 'ENOENT') throw error;
            });
            change.previousPhotoRemoved = previousPhotoBytes !== null;
        }

        return change;
    } catch (error) {
        await rollbackProfilePhotoChange(change).catch(rollbackError => {
            console.error('Rollback Agent Profile Photo Error:', rollbackError);
        });
        throw error;
    }
}

async function rollbackProfilePhotoChange(change) {
    if (change.metadataChanged) {
        if (change.previousMetadata) {
            const restorePath =
                `${change.metadataPath}.${crypto.randomUUID()}.tmp`;
            await fs.writeFile(
                restorePath,
                JSON.stringify(change.previousMetadata),
                { flag: 'wx' }
            );
            await fs.rename(restorePath, change.metadataPath);
        } else {
            await fs.unlink(change.metadataPath).catch(error => {
                if (error.code !== 'ENOENT') throw error;
            });
        }
    }

    if (
        change.previousPhotoRemoved &&
        change.previousPhotoPath &&
        change.previousPhotoBytes
    ) {
        await fs.writeFile(change.previousPhotoPath, change.previousPhotoBytes, {
            flag: 'wx',
        });
    }
    if (change.newPhotoPath) {
        await fs.unlink(change.newPhotoPath).catch(error => {
            if (error.code !== 'ENOENT') throw error;
        });
    }
    if (change.temporaryMetadataPath) {
        await fs.unlink(change.temporaryMetadataPath).catch(error => {
            if (error.code !== 'ENOENT') throw error;
        });
    }
}

async function readTasks() {
    await fs.mkdir(TASKS_DIR, { recursive: true });

    try {
        const content = await fs.readFile(TASKS_FILE, 'utf8');
        const tasks = JSON.parse(content);

        if (!Array.isArray(tasks)) {
            throw new Error('Format tugas.json harus berupa array');
        }

        return tasks;
    } catch (error) {
        if (error.code === 'ENOENT') {
            await fs.writeFile(
                TASKS_FILE,
                '[]',
                'utf8'
            );

            return [];
        }

        throw error;
    }
}

async function writeTasks(tasks) {
    await fs.mkdir(TASKS_DIR, { recursive: true });

    const tempFile = `${TASKS_FILE}.tmp`;

    await fs.writeFile(
        tempFile,
        JSON.stringify(tasks, null, 2),
        'utf8'
    );

    await fs.rename(tempFile, TASKS_FILE);
}

function localDateString(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

function completeOverdueTasks(tasks, now = new Date()) {
    const today = localDateString(now);
    const completedAt = now.toISOString();
    let updated = false;

    for (const task of tasks) {
        const deadline = String(task.tenggat ?? task.deadline ?? '').trim();
        if (!/^\d{4}-\d{2}-\d{2}$/.test(deadline)) continue;

        const parsedDeadline = new Date(`${deadline}T00:00:00.000Z`);
        if (
            Number.isNaN(parsedDeadline.getTime()) ||
            parsedDeadline.toISOString().slice(0, 10) !== deadline ||
            deadline >= today ||
            String(task.status ?? task.STATUS ?? '') === 'Selesai'
        ) {
            continue;
        }

        task.status = 'Selesai';
        task.completedAt = task.completedAt ?? completedAt;
        task.updatedAt = completedAt;
        updated = true;
    }

    return updated;
}

async function completeOverdueTasksInStorage() {
    const tasks = await readTasks();
    if (completeOverdueTasks(tasks)) {
        await writeTasks(tasks);
    }
}

// ========================================
// ROLE / HAK AKSES
// ========================================

const ADMIN_ROLE_LEVELS = {
    HEAD_MARKETING: '1',
    HEAD_AGENT: '2',
    AGENT: '3',
};

const AGENCY_ROLE_CODES = {
    KD: 'HEAD_MARKETING',
    AD: 'HEAD_AGENT',
    AM: 'AGENT',
    AS: 'AGENT',
    WA: 'AGENT',
};

const AGENCY_SUBORDINATE_ROLES = {
    AD: ['AM', 'AS', 'WA'],
    AM: ['AS', 'WA'],
    AS: ['WA'],
};

function getAgencySubordinateRoles(agencyRole) {
    const normalizedRole = String(agencyRole ?? '').trim().toUpperCase();
    return AGENCY_SUBORDINATE_ROLES[normalizedRole] ?? null;
}

// Keep source job codes in the user data; this map only grants generic app access.
function resolveAppRole(user) {
    if (user?.C_AGENCY_JABATAN != null) {
        return AGENCY_ROLE_CODES[
            String(user.C_AGENCY_JABATAN).trim().toUpperCase()
        ] ?? 'UNKNOWN';
    }

    const level = String(user?.LEVEL_USER ?? '').trim();

    if (level === ADMIN_ROLE_LEVELS.HEAD_MARKETING) {
        return 'HEAD_MARKETING';
    }
    if (level === ADMIN_ROLE_LEVELS.HEAD_AGENT) {
        return 'HEAD_AGENT';
    }
    if (level === ADMIN_ROLE_LEVELS.AGENT) {
        return 'AGENT';
    }

    return 'UNKNOWN';
}

function getAuthenticatedUserId(user) {
    return user?.I_AGEN ?? user?.STAMBUK;
}

function requireRoles(...allowedRoles) {
    return (req, res, next) => {
        const role = req.authUser?.APP_ROLE ?? resolveAppRole(req.authUser);

        if (!allowedRoles.includes(role)) {
            return res.status(403).json({
                success: false,
                message: 'Anda tidak memiliki akses ke fitur ini',
                appRole: role,
            });
        }

        req.authRole = role;
        next();
    };
}

function requireLeadership(req, res, next) {
    return requireRoles(
        'HEAD_MARKETING',
        'HEAD_AGENT'
    )(req, res, next);
}

function requireAgentViewer(req, res, next) {
    const role = req.authUser?.APP_ROLE ?? resolveAppRole(req.authUser);
    const agencyRole = String(req.authUser?.C_AGENCY_JABATAN ?? '')
        .trim()
        .toUpperCase();

    if (
        ['HEAD_MARKETING', 'HEAD_AGENT'].includes(role) ||
        getAgencySubordinateRoles(agencyRole) !== null
    ) {
        req.authRole = role;
        next();
        return;
    }

    return res.status(403).json({
        success: false,
        message: 'Anda tidak memiliki akses untuk melihat daftar agen',
        appRole: role,
    });
}

// ========================================
// AUTHENTICATION
// ========================================

function authenticate(req, res, next) {
    const authorization = req.headers.authorization;

    if (
        !authorization ||
        !authorization.startsWith('Bearer ')
    ) {
        return res.status(401).json({
            success: false,
            message: 'Token autentikasi wajib disertakan',
        });
    }

    const token = authorization.slice(7);
    const user = activeSessions.get(token);

    if (!user) {
        return res.status(401).json({
            success: false,
            message: 'Token tidak valid atau sesi sudah berakhir',
        });
    }

    req.authUser = user;
    next();
}

// ========================================
// ROOT
// ========================================

app.get('/', (req, res) => {
    res.json({
        message: 'Agent Intelligence Tracker API',
        status: 'running',
    });
});

// ========================================
// TEST DATABASE
// ========================================

app.get('/api/test-db', async (req, res) => {
    let connection;

    try {
        connection = await getConnection();

        const result = await connection.execute(
            'SELECT 1 AS DB_CONNECTED FROM DUAL',
            {},
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        return res.json({
            success: true,
            message: 'Berhasil terhubung ke Oracle',
            data: result.rows,
        });
    } catch (error) {
        console.error('Test DB Error:', error);

        return res.status(500).json({
            success: false,
            message: 'Gagal terhubung ke Oracle',
            error: error.message,
        });
    } finally {
        if (connection) {
            await connection.close().catch(console.error);
        }
    }
});

// ========================================
// LOGIN
// ========================================

app.post('/api/login', async (req, res) => {
    const { stambuk, password } = req.body;

    if (!stambuk || !password) {
        return res.status(400).json({
            success: false,
            message: 'Stambuk dan password wajib diisi',
        });
    }

    let connection;

    try {
        connection = await getConnection();

        const agencyResult = await connection.execute(
            `
            SELECT
                b.I_AGEN,
                b.C_AGENCY_JABATAN,
                a.NAMA_DEPAN AS NAMA_AGEN,
                TO_CHAR(
                    b.D_LAHIR,
                    'DD FMMonth YYYY',
                    'NLS_DATE_LANGUAGE=INDONESIAN'
                ) AS TANGGAL_LAHIR,
                TO_CHAR(b.D_LAHIR, 'YYYY-MM-DD') AS TANGGAL_LAHIR_ISO,
                a.TANGGAL_LISENSI,
                COALESCE(a.NOMOR_HP, b.I_TELEPON_HP) AS NOMOR_HP,
                b.I_TELEPON_HP,
                a.ALAMAT,
                b.A_EMAIL,
                b.A_EMAIL AS EMAIL,
                c.KODE_KANTOR,
                c.NAMA_KANTOR
            FROM TM_AGENCY2 b
            LEFT JOIN DAFTAR_AGEN a
                ON a.NOMOR_AGEN = b.I_AGEN
            LEFT JOIN DAFTAR_KANTOR c
                ON a.NOMOR_KANTOR = c.NOMOR_KANTOR
            WHERE b.I_AGEN = :stambuk
              AND b.N_PASSWORD = :password
            `,
            { stambuk, password },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        if (agencyResult.rows.length > 0) {
            const user = agencyResult.rows[0];
            const appRole = resolveAppRole(user);

            if (appRole === 'UNKNOWN') {
                return res.status(403).json({
                    success: false,
                    message: 'Kode jabatan belum dikenali. Hubungi administrator.',
                });
            }

            const token = crypto.randomBytes(32).toString('hex');
            const authenticatedUser = { ...user, APP_ROLE: appRole };
            activeSessions.set(token, authenticatedUser);

            return res.json({
                success: true,
                message: 'Login berhasil',
                token,
                user: authenticatedUser,
            });
        }

        const adminResult = await connection.execute(
            `
            SELECT
                STAMBUK,
                NAMA,
                KANTOR,
                EMAIL,
                LEVEL_USER,
                AKTIF,
                JBT,
                WARNA,
                LAYAR,
                EXPIRED
            FROM DATA_USER
            WHERE STAMBUK = :stambuk
              AND PASSWORD_USER = :password
            `,
            { stambuk, password },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        if (adminResult.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Stambuk atau password salah',
            });
        }

        const user = adminResult.rows[0];

        if (Number(user.AKTIF) !== 1) {
            return res.status(403).json({
                success: false,
                message: 'Akun tidak aktif',
            });
        }

        const appRole = resolveAppRole(user);

        if (appRole === 'UNKNOWN') {
            return res.status(403).json({
                success: false,
                message:
                    'LEVEL_USER belum dikenali. Hubungi administrator.',
            });
        }

        const token = crypto.randomBytes(32).toString('hex');

        // Simpan data user asli di sesi.
        activeSessions.set(token, user);

        return res.json({
            success: true,
            message: 'Login berhasil',
            token,
            user: {
                ...user,
                APP_ROLE: appRole,
            },
        });
    } catch (error) {
        console.error('Oracle Login Error:', error);

        return res.status(500).json({
            success: false,
            message: 'Terjadi kesalahan pada server',
        });
    } finally {
        if (connection) {
            await connection.close().catch(console.error);
        }
    }
});

// ========================================
// PROFIL PENGGUNA LOGIN
// ========================================

app.get('/api/auth/me', authenticate, (req, res) => {
    const appRole = req.authUser.APP_ROLE ?? resolveAppRole(req.authUser);

    return res.json({
        success: true,
        user: {
            ...req.authUser,
            APP_ROLE: appRole,
        },
        permissions: {
            viewAllBranches: appRole === 'HEAD_MARKETING',
            viewBranchAgents: [
                'HEAD_MARKETING',
                'HEAD_AGENT',
            ].includes(appRole),
            manageOwnTasks: appRole === 'AGENT',
        },
    });
});

app.patch(
    '/api/auth/profile',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res, next) => {
        if (!req.is('multipart/form-data')) return next();

        profileUpdateUpload.single('photo')(req, res, error => {
            if (error) {
                if (error instanceof multer.MulterError) {
                    const statusCode = error.code === 'LIMIT_FILE_SIZE'
                        ? 413
                        : 400;
                    const message = error.code === 'LIMIT_FILE_SIZE'
                        ? 'Ukuran foto maksimal 5 MB'
                        : 'Data perubahan profil tidak valid';
                    return res.status(statusCode).json({
                        success: false,
                        message,
                    });
                }
                return next(error);
            }
            return next();
        });
    },
    async (req, res) => {
        const agentId = String(req.authUser.I_AGEN ?? '').trim();
        if (!agentId) {
            return res.status(403).json({
                success: false,
                message: 'Profil agen tidak ditemukan pada sesi ini',
            });
        }

        let profileData = req.body ?? {};
        if (req.is('multipart/form-data')) {
            try {
                profileData = JSON.parse(req.body?.profile ?? '{}');
            } catch {
                return res.status(400).json({
                    success: false,
                    message: 'Data perubahan profil tidak valid',
                });
            }
        }
        if (
            profileData === null ||
            typeof profileData !== 'object' ||
            Array.isArray(profileData)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Data perubahan profil tidak valid',
            });
        }

        const normalizeOptionalText = (value, fieldName) => {
            if (value == null) return null;
            if (typeof value !== 'string') {
                throw new Error(`${fieldName} tidak valid`);
            }
            const normalized = value.trim();
            return normalized || null;
        };

        let normalizedPhone;
        let normalizedEmail;
        let normalizedAddress;
        let normalizedBirthDate;
        try {
            normalizedPhone = normalizeOptionalText(
                profileData.phone,
                'Nomor telepon'
            );
            normalizedEmail = normalizeOptionalText(profileData.email, 'Email');
            normalizedAddress = normalizeOptionalText(
                profileData.address,
                'Alamat'
            );
            normalizedBirthDate = normalizeOptionalText(
                profileData.birthDate,
                'Tanggal lahir'
            );
        } catch (error) {
            return res.status(400).json({
                success: false,
                message: error.message,
            });
        }

        const removePhoto = profileData.removePhoto === true;
        if (
            (profileData.removePhoto != null &&
                typeof profileData.removePhoto !== 'boolean') ||
            (removePhoto && req.file)
        ) {
            return res.status(400).json({
                success: false,
                message: 'Perubahan foto profil tidak valid',
            });
        }

        const parsedBirthDate = normalizedBirthDate
            ? new Date(`${normalizedBirthDate}T00:00:00.000Z`)
            : null;

        if (
            (normalizedPhone != null &&
                !/^[0-9+().\-\s]{8,20}$/.test(normalizedPhone)) ||
            (normalizedEmail != null &&
                (normalizedEmail.length > 254 ||
                    !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail))) ||
            (normalizedAddress != null && normalizedAddress.length > 500) ||
            (normalizedBirthDate != null &&
                (!/^\d{4}-\d{2}-\d{2}$/.test(normalizedBirthDate) ||
                    Number.isNaN(parsedBirthDate.getTime()) ||
                    parsedBirthDate.toISOString().slice(0, 10) !==
                        normalizedBirthDate ||
                    parsedBirthDate > new Date()))
        ) {
            return res.status(400).json({
                success: false,
                message:
                    'Periksa kembali format data profil yang diisi',
            });
        }

        const photoType = req.file
            ? getProfilePhotoType(req.file.buffer)
            : null;
        if (req.file && !photoType) {
            return res.status(415).json({
                success: false,
                message: 'Format foto harus JPEG, PNG, atau WebP',
            });
        }

        let connection;
        let photoChange;
        let databaseCommitted = false;

        try {
            connection = await getConnection();

            const profileResult = await connection.execute(
                `
                SELECT
                    TO_CHAR(D_LAHIR, 'YYYY-MM-DD') AS TANGGAL_LAHIR_ISO
                FROM TM_AGENCY2
                WHERE I_AGEN = :agentId
                FOR UPDATE
                `,
                { agentId },
                { outFormat: oracledb.OUT_FORMAT_OBJECT }
            );

            if (profileResult.rows.length !== 1) {
                await connection.rollback();
                return res.status(404).json({
                    success: false,
                    message: 'Data profil agen tidak ditemukan',
                });
            }

            if (
                normalizedBirthDate &&
                profileResult.rows[0].TANGGAL_LAHIR_ISO
            ) {
                await connection.rollback();
                return res.status(409).json({
                    success: false,
                    message: 'Tanggal lahir yang sudah diisi tidak dapat diubah',
                });
            }

            if (req.file || removePhoto) {
                photoChange = await applyProfilePhotoChange({
                    agentId,
                    photoFile: req.file,
                    photoType,
                    removePhoto,
                });
            }

            const agentFields = [];
            const agentBinds = { agentId };
            if (normalizedPhone != null) {
                agentFields.push('NOMOR_HP = :phone');
                agentBinds.phone = normalizedPhone;
            }
            if (normalizedAddress != null) {
                agentFields.push('ALAMAT = :address');
                agentBinds.address = normalizedAddress;
            }
            if (agentFields.length) {
                const agentResult = await connection.execute(
                    `
                    UPDATE DAFTAR_AGEN
                    SET ${agentFields.join(', ')}
                    WHERE NOMOR_AGEN = :agentId
                    `,
                    agentBinds
                );
                if (agentResult.rowsAffected !== 1) {
                    throw new Error('Data profil agen tidak ditemukan');
                }
            }

            const agencyFields = [];
            const agencyBinds = { agentId };
            if (normalizedEmail != null) {
                agencyFields.push('A_EMAIL = :email');
                agencyBinds.email = normalizedEmail;
            }
            if (normalizedBirthDate != null) {
                agencyFields.push(
                    "D_LAHIR = TO_DATE(:birthDate, 'YYYY-MM-DD')"
                );
                agencyBinds.birthDate = normalizedBirthDate;
            }
            if (agencyFields.length) {
                const agencyResult = await connection.execute(
                    `
                    UPDATE TM_AGENCY2
                    SET ${agencyFields.join(', ')}
                    WHERE I_AGEN = :agentId
                    ${normalizedBirthDate
                        ? 'AND D_LAHIR IS NULL'
                        : ''}
                    `,
                    agencyBinds
                );
                if (agencyResult.rowsAffected !== 1) {
                    throw new Error(
                        normalizedBirthDate
                            ? 'Tanggal lahir yang sudah diisi tidak dapat diubah'
                            : 'Data profil agen tidak ditemukan'
                    );
                }
            }

            await connection.commit();
            databaseCommitted = true;

            if (normalizedPhone != null) {
                Object.assign(req.authUser, {
                    NOMOR_HP: normalizedPhone,
                    I_TELEPON_HP: normalizedPhone,
                });
            }
            if (normalizedEmail != null) {
                Object.assign(req.authUser, {
                    A_EMAIL: normalizedEmail,
                    EMAIL: normalizedEmail,
                });
            }
            if (normalizedAddress != null) {
                req.authUser.ALAMAT = normalizedAddress;
            }
            if (normalizedBirthDate) {
                req.authUser.TANGGAL_LAHIR_ISO = normalizedBirthDate;
                req.authUser.TANGGAL_LAHIR = parsedBirthDate.toLocaleDateString(
                    'id-ID',
                    {
                        timeZone: 'UTC',
                        day: 'numeric',
                        month: 'long',
                        year: 'numeric',
                    }
                );
            }

            return res.json({
                success: true,
                message: 'Profil berhasil diperbarui',
                user: {
                    ...req.authUser,
                    APP_ROLE: req.authRole,
                },
            });
        } catch (error) {
            console.error('Update Agent Profile Error:', error);
            if (connection && !databaseCommitted) {
                await connection.rollback().catch(console.error);
            }
            if (photoChange && !databaseCommitted) {
                await rollbackProfilePhotoChange(photoChange).catch(
                    rollbackError => {
                        console.error(
                            'Rollback Agent Profile Photo Error:',
                            rollbackError
                        );
                    }
                );
            }

            const statusCode = error.message ===
                'Tanggal lahir yang sudah diisi tidak dapat diubah'
                ? 409
                : error.message === 'Data profil agen tidak ditemukan'
                    ? 404
                    : 500;
            return res.status(statusCode).json({
                success: false,
                message: statusCode === 500
                    ? 'Gagal memperbarui profil agen'
                    : error.message,
            });
        } finally {
            if (connection) {
                await connection.close().catch(console.error);
            }
        }
    }
);

app.get(
    '/api/auth/profile/photo',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    async (req, res) => {
        const agentId = String(req.authUser.I_AGEN ?? '').trim();
        if (!agentId) {
            return res.status(403).json({
                success: false,
                message: 'Profil agen tidak ditemukan pada sesi ini',
            });
        }

        try {
            const metadata = await readProfilePhotoMetadata(agentId);
            if (!metadata) {
                return res.status(404).json({
                    success: false,
                    message: 'Foto profil belum diunggah',
                });
            }

            const photo = await fs.readFile(
                path.join(PROFILE_PHOTO_DIR, metadata.filename)
            );
            res.set({
                'Content-Type': metadata.mimeType,
                'Cache-Control': 'private, no-store',
                'X-Content-Type-Options': 'nosniff',
            });
            return res.send(photo);
        } catch (error) {
            console.error('Get Agent Profile Photo Error:', error);
            return res.status(500).json({
                success: false,
                message: 'Gagal mengambil foto profil',
            });
        }
    }
);

app.get(
    '/api/agents/:agentId/profile/photo',
    authenticate,
    async (req, res) => {
        let connection;

        try {
            const agentId = String(req.params.agentId ?? '').trim();
            const authenticatedAgentId = String(
                getAuthenticatedUserId(req.authUser) ?? ''
            ).trim();
            const role = req.authUser?.APP_ROLE ?? resolveAppRole(req.authUser);
            const agencyRole = String(req.authUser?.C_AGENCY_JABATAN ?? '')
                .trim()
                .toUpperCase();
            const subordinateRoles = getAgencySubordinateRoles(agencyRole);
            const ownBranch = String(
                req.authUser?.KODE_KANTOR ?? req.authUser?.KANTOR ?? ''
            ).trim().toUpperCase();
            const isSelf = agentId === authenticatedAgentId;
            const canViewOtherAgents =
                ['HEAD_MARKETING', 'HEAD_AGENT'].includes(role) ||
                subordinateRoles !== null;

            if (!agentId) {
                return res.status(400).json({
                    success: false,
                    message: 'ID agen wajib diisi',
                });
            }
            if (!isSelf && !canViewOtherAgents) {
                return res.status(403).json({
                    success: false,
                    message: 'Anda tidak memiliki akses untuk melihat foto agen',
                });
            }
            if (!isSelf && subordinateRoles && !ownBranch) {
                return res.status(403).json({
                    success: false,
                    message: 'Kode kantor akun tidak tersedia.',
                });
            }

            connection = await getConnection();
            const binds = { agentId };
            const conditions = [
                'a.STATUS = 1',
                'b.I_AGEN = :agentId',
            ];

            if (!isSelf && subordinateRoles) {
                conditions.push('UPPER(TRIM(c.KODE_KANTOR)) = :scopeKantor');
                binds.scopeKantor = ownBranch;
                const roleBindNames = subordinateRoles.map((subordinateRole, index) => {
                    const bindName = `scopeRole${index}`;
                    binds[bindName] = subordinateRole;
                    return `:${bindName}`;
                });
                conditions.push(
                    `UPPER(b.C_AGENCY_JABATAN) IN (${roleBindNames.join(', ')})`
                );
            }

            const agentResult = await connection.execute(
                `
                SELECT b.I_AGEN
                FROM DAFTAR_AGEN a
                INNER JOIN TM_AGENCY2 b
                    ON a.NOMOR_AGEN = b.I_AGEN
                INNER JOIN DAFTAR_KANTOR c
                    ON a.NOMOR_KANTOR = c.NOMOR_KANTOR
                WHERE ${conditions.join(' AND ')}
                `,
                binds,
                { outFormat: oracledb.OUT_FORMAT_OBJECT }
            );
            if (!agentResult.rows.length) {
                return res.status(404).json({
                    success: false,
                    message: 'Agen tidak ditemukan atau tidak dapat diakses',
                });
            }

            const metadata = await readProfilePhotoMetadata(agentId);
            if (!metadata) {
                return res.status(404).json({
                    success: false,
                    message: 'Foto profil belum diunggah',
                });
            }

            const photo = await fs.readFile(
                path.join(PROFILE_PHOTO_DIR, metadata.filename)
            );
            res.set({
                'Content-Type': metadata.mimeType,
                'Cache-Control': 'private, no-store',
                'X-Content-Type-Options': 'nosniff',
            });
            return res.send(photo);
        } catch (error) {
            console.error('Get Agent Profile Photo By ID Error:', error);
            return res.status(500).json({
                success: false,
                message: 'Gagal mengambil foto profil agen',
            });
        } finally {
            if (connection) {
                await connection.close().catch(console.error);
            }
        }
    }
);

app.post(
    '/api/auth/profile/photo',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res, next) => {
        profilePhotoUpload.single('photo')(req, res, error => {
            if (error) {
                if (error instanceof multer.MulterError) {
                    const statusCode = error.code === 'LIMIT_FILE_SIZE'
                        ? 413
                        : 400;
                    const message = error.code === 'LIMIT_FILE_SIZE'
                        ? 'Ukuran foto maksimal 5 MB'
                        : 'Unggahan foto tidak valid';
                    return res.status(statusCode).json({
                        success: false,
                        message,
                    });
                }
                return next(error);
            }
            return next();
        });
    },
    async (req, res) => {
        const agentId = String(req.authUser.I_AGEN ?? '').trim();
        if (!agentId) {
            return res.status(403).json({
                success: false,
                message: 'Profil agen tidak ditemukan pada sesi ini',
            });
        }
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: 'Pilih foto profil terlebih dahulu',
            });
        }

        const photoType = getProfilePhotoType(req.file.buffer);
        if (!photoType) {
            return res.status(415).json({
                success: false,
                message: 'Format foto harus JPEG, PNG, atau WebP',
            });
        }

        const metadataPath = getProfilePhotoMetadataPath(agentId);
        const filename = `${crypto.randomUUID()}${photoType.extension}`;
        const tempMetadataPath = `${metadataPath}.${crypto.randomUUID()}.tmp`;
        const newPhotoPath = path.join(PROFILE_PHOTO_DIR, filename);
        let previousMetadata;

        try {
            await fs.mkdir(PROFILE_PHOTO_DIR, { recursive: true });
            previousMetadata = await readProfilePhotoMetadata(agentId);
            await fs.writeFile(newPhotoPath, req.file.buffer, { flag: 'wx' });
            await fs.writeFile(
                tempMetadataPath,
                JSON.stringify({
                    filename,
                    mimeType: photoType.mimeType,
                    updatedAt: new Date().toISOString(),
                }),
                { flag: 'wx' }
            );
            await fs.rename(tempMetadataPath, metadataPath);

            if (
                previousMetadata &&
                previousMetadata.filename !== filename
            ) {
                await fs.unlink(
                    path.join(PROFILE_PHOTO_DIR, previousMetadata.filename)
                ).catch(error => {
                    if (error.code !== 'ENOENT') {
                        console.error('Remove previous profile photo Error:', error);
                    }
                });
            }

            return res.json({
                success: true,
                message: 'Foto profil berhasil diperbarui',
                photo: {
                    updatedAt: new Date().toISOString(),
                },
            });
        } catch (error) {
            await fs.unlink(newPhotoPath).catch(cleanupError => {
                if (cleanupError.code !== 'ENOENT') {
                    console.error('Remove incomplete profile photo Error:', cleanupError);
                }
            });
            await fs.unlink(tempMetadataPath).catch(cleanupError => {
                if (cleanupError.code !== 'ENOENT') {
                    console.error('Remove temporary profile metadata Error:', cleanupError);
                }
            });
            console.error('Update Agent Profile Photo Error:', error);
            return res.status(500).json({
                success: false,
                message: 'Gagal menyimpan foto profil di server',
            });
        }
    }
);

// ========================================
// LOGOUT
// ========================================

app.post('/api/logout', authenticate, (req, res) => {
    const token = req.headers.authorization.slice(7);

    stopAgentTracking(String(getAuthenticatedUserId(req.authUser) ?? ''));
    activeSessions.delete(token);

    return res.json({
        success: true,
        message: 'Logout berhasil',
    });
});

// ========================================
// DAFTAR KANTOR
// Catatan: endpoint ini masih untuk kompatibilitas
// dengan homepage lama. Pembatasan akses perlu
// diselaraskan dengan navigasi Flutter berikutnya.
// ========================================

app.get('/api/kantor', async (req, res) => {
    let connection;

    try {
        connection = await getConnection();

        const result = await connection.execute(
            `
            SELECT
                k.*,
                m.ALAMAT_KANTOR AS ALAMAT_KANTOR_MUTASI
            FROM DAFTAR_KANTOR k
            LEFT JOIN MUTASI_KANTOR m
                ON m.NOMOR_KANTOR = k.NOMOR_KANTOR
            WHERE UPPER(k.NAMA_KANTOR) LIKE :officeName
            `,
            { officeName: '%SYARIAH%' },
            { outFormat: oracledb.OUT_FORMAT_OBJECT }
        );

        return res.json({
            success: true,
            message: 'Data kantor berhasil diambil',
            total: result.rows.length,
            data: result.rows,
        });
    } catch (error) {
        console.error('Oracle Kantor Error:', error);

        return res.status(500).json({
            success: false,
            message: 'Gagal mengambil data kantor',
        });
    } finally {
        if (connection) {
            await connection.close().catch(console.error);
        }
    }
});


/**
 * GET /api/agents
 * Mengambil profil agen dari:
 * DAFTAR_AGEN + TM_AGENCY2 + DAFTAR_KANTOR
 *
 * Query opsional:
 * ?search=anita
 * ?jabatan=WA
 * ?kantor=KHOS
 * ?search=anita&jabatan=WA&kantor=KHOS
 */
app.get('/api/agents', authenticate, async (req, res) => {
    let connection;

    try {
        const agencyRole = String(req.authUser?.C_AGENCY_JABATAN ?? '')
            .trim()
            .toUpperCase();
        const subordinateRoles = getAgencySubordinateRoles(agencyRole);
        const ownBranch = String(
            req.authUser?.KODE_KANTOR ?? req.authUser?.KANTOR ?? ''
        ).trim().toUpperCase();

        if (subordinateRoles && !ownBranch) {
            return res.status(403).json({
                success: false,
                message: 'Kode kantor akun tidak tersedia.',
            });
        }

        connection = await getConnection();

        const conditions = ['a.STATUS = 1'];
        const binds = {};

        const search = String(req.query.search ?? '').trim();
        const jabatan = String(req.query.jabatan ?? '')
            .trim()
            .toUpperCase();
        const kantor = String(req.query.kantor ?? '')
            .trim()
            .toUpperCase();

        if (search) {
            conditions.push(`
                (
                    UPPER(a.NAMA_DEPAN) LIKE :search
                    OR TO_CHAR(b.I_AGEN) LIKE :search
                    OR UPPER(b.A_EMAIL) LIKE :search
                    OR UPPER(a.NOMOR_HP) LIKE :search
                    OR UPPER(b.I_TELEPON_HP) LIKE :search
                )
            `);

            binds.search = `%${search.toUpperCase()}%`;
        }

        if (subordinateRoles) {
            conditions.push('UPPER(TRIM(c.KODE_KANTOR)) = :scopeKantor');
            binds.scopeKantor = ownBranch;

            const roleBindNames = subordinateRoles.map((role, index) => {
                const bindName = `scopeRole${index}`;
                binds[bindName] = role;
                return `:${bindName}`;
            });
            conditions.push(
                `UPPER(b.C_AGENCY_JABATAN) IN (${roleBindNames.join(', ')})`
            );
        } else {
            if (jabatan) {
                conditions.push(
                    'UPPER(b.C_AGENCY_JABATAN) = :jabatan'
                );
                binds.jabatan = jabatan;
            }

            if (kantor) {
                conditions.push(
                    'UPPER(TRIM(c.KODE_KANTOR)) = :kantor'
                );
                binds.kantor = kantor;
            }
        }

        const whereClause = conditions.length
            ? `WHERE ${conditions.join(' AND ')}`
            : '';

        const result = await connection.execute(
            `
            SELECT
                a.NAMA_DEPAN AS NAMA_AGEN,
                b.I_AGEN AS NOMOR_AGEN,
                TO_CHAR(
                    b.D_LAHIR,
                    'DD FMMonth YYYY',
                    'NLS_DATE_LANGUAGE=INDONESIAN'
                ) AS TANGGAL_LAHIR,
                a.TANGGAL_LISENSI,
                COALESCE(a.NOMOR_HP, b.I_TELEPON_HP) AS NOMOR_HP,
                b.I_TELEPON_HP,
                a.ALAMAT,
                b.A_EMAIL,
                b.A_EMAIL AS EMAIL,
                b.C_AGENCY_JABATAN,
                c.KODE_KANTOR,
                c.NAMA_KANTOR
            FROM DAFTAR_AGEN a
            INNER JOIN TM_AGENCY2 b
                ON a.NOMOR_AGEN = b.I_AGEN
            INNER JOIN DAFTAR_KANTOR c
                ON a.NOMOR_KANTOR = c.NOMOR_KANTOR
            ${whereClause}
            ORDER BY a.NAMA_DEPAN ASC
            `,
            binds,
            {
                outFormat: oracledb.OUT_FORMAT_OBJECT,
            }
        );

        return res.json({
            success: true,
            message: 'Data agen berhasil diambil',
            total: result.rows.length,
            data: result.rows,
        });
    } catch (error) {
        console.error('Oracle Agent List Error:', error);

        return res.status(500).json({
            success: false,
            message: 'Gagal mengambil data agen',
            // Detail error hanya di log server.
        });
    } finally {
        if (connection) {
            await connection.close().catch(console.error);
        }
    }
});

app.get(
    '/api/dashboard/agent-stats',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT'),
    async (req, res) => {
        let connection;

        try {
            const conditions = ['a.STATUS = 1'];
            const binds = {};
            let branch = null;

            if (req.authRole === 'HEAD_AGENT') {
                branch = String(
                    req.authUser.KODE_KANTOR ?? req.authUser.KANTOR ?? ''
                )
                    .trim()
                    .toUpperCase();

                if (!branch) {
                    return res.status(403).json({
                        success: false,
                        message: 'Kode kantor akun kepala agen tidak tersedia.',
                    });
                }

                conditions.push('UPPER(c.KODE_KANTOR) = :kantor');
                binds.kantor = branch;
            }

            connection = await getConnection();

            const whereClause = conditions.length
                ? `WHERE ${conditions.join(' AND ')}`
                : '';
            const result = await connection.execute(
                `
                SELECT DISTINCT b.I_AGEN AS NOMOR_AGEN
                FROM DAFTAR_AGEN a
                INNER JOIN TM_AGENCY2 b
                    ON a.NOMOR_AGEN = b.I_AGEN
                INNER JOIN DAFTAR_KANTOR c
                    ON a.NOMOR_KANTOR = c.NOMOR_KANTOR
                ${whereClause}
                `,
                binds,
                { outFormat: oracledb.OUT_FORMAT_OBJECT }
            );

            const registeredAgentIds = new Set(
                result.rows
                    .map(row =>
                        String(row.NOMOR_AGEN ?? '')
                            .trim()
                            .toUpperCase()
                    )
                    .filter(Boolean)
            );
            const onlineAgentIds = new Set(
                Array.from(activeAgents.values())
                    .filter(
                        agent =>
                            agent.latitude !== null &&
                            agent.longitude !== null &&
                            (req.authRole !== 'HEAD_AGENT' ||
                                String(agent.kantor ?? '')
                                    .trim()
                                    .toUpperCase() === branch)
                    )
                    .map(agent =>
                        String(agent.stambuk ?? '')
                            .trim()
                            .toUpperCase()
                    )
                    .filter(agentId => registeredAgentIds.has(agentId))
            );
            const totalAgents = registeredAgentIds.size;
            const onlineAgents = onlineAgentIds.size;

            return res.json({
                success: true,
                data: {
                    totalAgents,
                    onlineAgents,
                    offlineAgents: totalAgents - onlineAgents,
                },
            });
        } catch (error) {
            console.error('Dashboard Agent Stats Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal mengambil statistik agen.',
            });
        } finally {
            if (connection) {
                await connection.close().catch(console.error);
            }
        }
    }
);


// ========================================
// TRACKING: MULAI
// ========================================

app.post(
    '/api/agent-tracking/start',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res) => {
        const user = req.authUser;
        const stambuk = String(getAuthenticatedUserId(user) ?? '');

        if (activeAgents.has(stambuk)) {
            return res.status(409).json({
                success: false,
                message: 'Anda sudah memulai tracking',
                data: activeAgents.get(stambuk),
            });
        }

        const agent = {
            stambuk,
            nama: user.NAMA_AGEN ?? user.NAMA,
            kantor: user.KODE_KANTOR ?? user.KANTOR,
            level: user.C_AGENCY_JABATAN ?? user.LEVEL_USER,
            latitude: null,
            longitude: null,
            accuracy: null,
            speed: null,
            locationSuspicious: false,
            locationWarnings: [],
            startedAt: new Date().toISOString(),
            lastUpdated: null,
            status: 'active',
            isTracking: true,
        };

        activeAgents.set(stambuk, agent);

        return res.status(201).json({
            success: true,
            message: 'Tracking berhasil dimulai',
            data: agent,
        });
    }
);

// ========================================
// TRACKING: STATUS PENGGUNA
// ========================================

app.get(
    '/api/agent-tracking/status',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res) => {
        const stambuk = String(getAuthenticatedUserId(req.authUser) ?? '');
        const agent = activeAgents.get(stambuk) ?? null;

        return res.json({
            success: true,
            active: agent !== null,
            data: agent,
        });
    }
);

// ========================================
// TRACKING: UPDATE LOKASI
// ========================================

app.post(
    '/api/agent-tracking/location',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res) => {
        const stambuk = String(getAuthenticatedUserId(req.authUser) ?? '');
        const agent = activeAgents.get(stambuk);

        if (!agent) {
            return res.status(409).json({
                success: false,
                message: 'Mulai tracking terlebih dahulu',
            });
        }

        const {
            latitude,
            longitude,
            accuracy,
            speed,
            isMocked,
        } = req.body;

        const lat = Number(latitude);
        const lng = Number(longitude);

        if (
            latitude === undefined ||
            longitude === undefined ||
            latitude === null ||
            longitude === null ||
            !Number.isFinite(lat) ||
            !Number.isFinite(lng) ||
            lat < -90 ||
            lat > 90 ||
            lng < -180 ||
            lng > 180
        ) {
            return res.status(400).json({
                success: false,
                message: 'Koordinat latitude atau longitude tidak valid',
            });
        }

        const receivedAt = new Date();
        const anomalies = getLocationAnomalies(
            agent,
            { latitude: lat, longitude: lng },
            receivedAt,
            isMocked === true
        );

        agent.latitude = lat;
        agent.longitude = lng;
        agent.locationSuspicious =
            agent.locationSuspicious || anomalies.length > 0;
        agent.locationWarnings = [
            ...new Set([...(agent.locationWarnings ?? []), ...anomalies]),
        ];

        agent.accuracy =
            accuracy != null && Number.isFinite(Number(accuracy))
                ? Number(accuracy)
                : null;

        agent.speed =
            speed != null && Number.isFinite(Number(speed))
                ? Number(speed)
                : null;

        agent.lastUpdated = receivedAt.toISOString();
        agent.status = 'active';
        agent.isTracking = true;

        activeAgents.set(stambuk, agent);
        lastKnownAgents.set(stambuk, { ...agent });

        return res.json({
            success: true,
            message: 'Lokasi berhasil diperbarui',
            data: agent,
        });
    }
);

// ========================================
// TRACKING: SELESAI
// ========================================

app.post(
    '/api/agent-tracking/stop',
    authenticate,
    requireRoles('HEAD_MARKETING', 'HEAD_AGENT', 'AGENT'),
    (req, res) => {
        const stambuk = String(getAuthenticatedUserId(req.authUser) ?? '');
        const agent = stopAgentTracking(stambuk);

        return res.json({
            success: true,
            message: agent
                ? 'Tracking berhasil dihentikan'
                : 'Tidak ada tracking aktif',
            stambuk,
            stoppedAt: agent?.stoppedAt ?? null,
            data: agent,
        });
    }
);

// ========================================
// TRACKING: DAFTAR AGEN AKTIF
// Kepala Pemasaran: seluruh cabang
// Kepala Agen: cabangnya sendiri
// ========================================

app.get(
    '/api/agent-tracking/agents',
    authenticate,
    requireAgentViewer,
    (req, res) => {
        const filterKantor = req.query.kantor
            ? String(req.query.kantor).trim().toUpperCase()
            : null;

        const latestAgents = new Map(lastKnownAgents);
        for (const [agentId, agent] of activeAgents) {
            latestAgents.set(agentId, agent);
        }
        let agents = Array.from(latestAgents.values());

        const subordinateRoles = getAgencySubordinateRoles(
            req.authUser?.C_AGENCY_JABATAN
        );

        if (subordinateRoles) {
            const ownBranch = String(
                req.authUser.KODE_KANTOR ?? req.authUser.KANTOR ?? ''
            ).trim().toUpperCase();

            agents = agents.filter(
                agent =>
                    String(agent.kantor ?? '')
                        .trim()
                        .toUpperCase() === ownBranch &&
                    subordinateRoles.includes(
                        String(agent.level ?? '').trim().toUpperCase()
                    )
            );
        } else if (req.authRole === 'HEAD_AGENT') {
            const ownBranch = String(
                req.authUser.KODE_KANTOR ?? req.authUser.KANTOR ?? ''
            ).trim().toUpperCase();

            agents = agents.filter(
                agent =>
                    String(agent.kantor ?? '')
                        .trim()
                        .toUpperCase() === ownBranch
            );
        } else if (filterKantor) {
            agents = agents.filter(
                agent =>
                    String(agent.kantor ?? '')
                        .trim()
                        .toUpperCase() === filterKantor
            );
        }

        // Hanya agen yang sudah mengirim koordinat.
        agents = agents.filter(
            agent =>
                agent.latitude !== null &&
                agent.longitude !== null
        );

        return res.json({
            success: true,
            total: agents.length,
            data: agents,
        });
    }
);

// ========================================
// TUGAS AGEN: LIHAT DAFTAR TUGAS
// ========================================

app.get(
    '/api/agents/:agentId/tasks',
    authenticate,
    async (req, res) => {
        try {
            const agentId = String(req.params.agentId).trim();

            if (!agentId) {
                return res.status(400).json({
                    success: false,
                    message: 'ID agen wajib diisi',
                });
            }

            const tasks = await readTasks();
            if (completeOverdueTasks(tasks)) {
                await writeTasks(tasks);
            }

            const agentTasks = tasks
                .filter(task => task.agentId === agentId)
                .sort((a, b) =>
                    b.createdAt.localeCompare(a.createdAt)
                );

            return res.json({
                success: true,
                total: agentTasks.length,
                data: agentTasks,
            });
        } catch (error) {
            console.error('Get Agent Tasks Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal mengambil tugas agen',
            });
        }
    }
);

// ========================================
// TUGAS AGEN: TAMBAH TUGAS
// ========================================

app.post(
    '/api/agents/:agentId/tasks',
    authenticate,
    requireRoles('HEAD_AGENT', 'AGENT'),
    async (req, res) => {
        try {
            const agentId = String(req.params.agentId).trim();

            const judul = String(req.body.judul ?? '').trim();
            const deskripsi = String(
                req.body.deskripsi ?? ''
            ).trim();

            const tenggat = req.body.tenggat
                ? String(req.body.tenggat).trim()
                : null;

            if (!agentId || !judul) {
                return res.status(400).json({
                    success: false,
                    message: 'ID agen dan judul tugas wajib diisi',
                });
            }

            if (judul.length > 200) {
                return res.status(400).json({
                    success: false,
                    message: 'Judul maksimal 200 karakter',
                });
            }

            if (deskripsi.length > 5000) {
                return res.status(400).json({
                    success: false,
                    message: 'Deskripsi maksimal 5000 karakter',
                });
            }

            if (
                tenggat &&
                !/^\d{4}-\d{2}-\d{2}$/.test(tenggat)
            ) {
                return res.status(400).json({
                    success: false,
                    message: 'Format tenggat harus YYYY-MM-DD',
                });
            }

            const tasks = await readTasks();
            const now = new Date().toISOString();

            const newTask = {
                id: crypto.randomUUID(),
                agentId,
                judul,
                deskripsi,
                tenggat,
                status: 'Belum dimulai',
                createdBy: String(
                    getAuthenticatedUserId(req.authUser) ?? ''
                ),
                createdAt: now,
                updatedAt: now,
                completedAt: null,
            };

            tasks.push(newTask);
            completeOverdueTasks(tasks);

            await writeTasks(tasks);

            return res.status(201).json({
                success: true,
                message: 'Tugas berhasil disimpan',
                data: newTask,
            });
        } catch (error) {
            console.error('Create Agent Task Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal menyimpan tugas',
            });
        }
    }
);

// ========================================
// TUGAS AGEN: EDIT TUGAS
// ========================================

app.patch(
    '/api/tasks/:taskId',
    authenticate,
    requireRoles('HEAD_AGENT', 'AGENT'),
    async (req, res) => {
        try {
            const taskId = String(req.params.taskId);
            const judul = String(req.body.judul ?? '').trim();
            const deskripsi = String(req.body.deskripsi ?? '').trim();
            const tenggat = String(req.body.tenggat ?? '').trim();

            if (!judul) {
                return res.status(400).json({
                    success: false,
                    message: 'Judul tugas wajib diisi',
                });
            }

            if (judul.length > 200) {
                return res.status(400).json({
                    success: false,
                    message: 'Judul maksimal 200 karakter',
                });
            }

            if (deskripsi.length > 5000) {
                return res.status(400).json({
                    success: false,
                    message: 'Deskripsi maksimal 5000 karakter',
                });
            }

            if (!/^\d{4}-\d{2}-\d{2}$/.test(tenggat)) {
                return res.status(400).json({
                    success: false,
                    message: 'Format tenggat harus YYYY-MM-DD',
                });
            }

            const tasks = await readTasks();
            const index = tasks.findIndex(task => task.id === taskId);

            if (index === -1) {
                return res.status(404).json({
                    success: false,
                    message: 'Tugas tidak ditemukan',
                });
            }

            tasks[index] = {
                ...tasks[index],
                judul,
                deskripsi,
                tenggat,
                updatedAt: new Date().toISOString(),
            };
            completeOverdueTasks([tasks[index]]);

            await writeTasks(tasks);

            return res.json({
                success: true,
                message: 'Tugas berhasil diperbarui',
                data: tasks[index],
            });
        } catch (error) {
            console.error('Update Agent Task Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal memperbarui tugas',
            });
        }
    }
);

// ========================================
// TUGAS AGEN: UBAH STATUS
// ========================================

app.patch(
    '/api/tasks/:taskId/status',
    authenticate,
    requireRoles('HEAD_AGENT', 'AGENT'),
    async (req, res) => {
        try {
            const taskId = String(req.params.taskId);

            const allowedStatuses = [
                'Belum dimulai',
                'Berjalan',
                'Selesai',
            ];

            const status = String(req.body.status ?? '');

            if (!allowedStatuses.includes(status)) {
                return res.status(400).json({
                    success: false,
                    message: 'Status tugas tidak valid',
                    allowedStatuses,
                });
            }

            const tasks = await readTasks();

            const index = tasks.findIndex(
                task => task.id === taskId
            );

            if (index === -1) {
                return res.status(404).json({
                    success: false,
                    message: 'Tugas tidak ditemukan',
                });
            }

            const taskWasCompleted = completeOverdueTasks([tasks[index]]);
            if (taskWasCompleted) {
                await writeTasks(tasks);
            }
            if (
                String(tasks[index].status ?? tasks[index].STATUS ?? '') ===
                    'Selesai' &&
                status !== 'Selesai'
            ) {
                return res.status(409).json({
                    success: false,
                    message: 'Status tugas yang sudah selesai tidak dapat diubah.',
                    data: tasks[index],
                });
            }

            tasks[index].status = status;
            tasks[index].updatedAt = new Date().toISOString();

            tasks[index].completedAt =
                status === 'Selesai'
                    ? tasks[index].completedAt ??
                      new Date().toISOString()
                    : null;

            await writeTasks(tasks);

            return res.json({
                success: true,
                message: 'Status tugas berhasil diperbarui',
                data: tasks[index],
            });
        } catch (error) {
            console.error('Update Task Status Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal memperbarui status tugas',
            });
        }
    }
);

// ========================================
// TUGAS AGEN: HAPUS TUGAS
// ========================================

app.delete(
    '/api/tasks/:taskId',
    authenticate,
    requireRoles('HEAD_AGENT', 'AGENT'),
    async (req, res) => {
        try {
            const taskId = String(req.params.taskId);
            const tasks = await readTasks();

            const index = tasks.findIndex(
                task => task.id === taskId
            );

            if (index === -1) {
                return res.status(404).json({
                    success: false,
                    message: 'Tugas tidak ditemukan',
                });
            }

            tasks.splice(index, 1);

            await writeTasks(tasks);

            return res.json({
                success: true,
                message: 'Tugas berhasil dihapus',
            });
        } catch (error) {
            console.error('Delete Agent Task Error:', error);

            return res.status(500).json({
                success: false,
                message: 'Gagal menghapus tugas',
            });
        }
    }
);

// ========================================
// START SERVER
// ========================================

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server berjalan di port ${PORT}`);
    console.log('Role agen menggunakan C_AGENCY_JABATAN; role admin menggunakan LEVEL_USER.');
    void completeOverdueTasksInStorage().catch(error => {
        console.error('Auto-complete overdue tasks Error:', error);
    });
    setInterval(() => {
        void completeOverdueTasksInStorage().catch(error => {
            console.error('Auto-complete overdue tasks Error:', error);
        });
    }, 60_000);
});
