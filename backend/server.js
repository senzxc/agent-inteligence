const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { getConnection } = require('./database');

const app = express();

const PORT = process.env.PORT || 3000;

// ========================================
// MIDDLEWARE
// ========================================

app.use(cors());
app.use(express.json());

// ========================================
// ROOT
// ========================================

app.get('/', (req, res) => {
    res.json({
        message: 'Agent Intelligence Tracker API',
        status: 'running',
    });
});

app.get('/api/test-db', async (req, res) => {
    try {
        const { getConnection } = require('./database');

        const connection = await getConnection();

        const result = await connection.execute(
            `SELECT * FROM DATA_USER FETCH FIRST 5 ROWS ONLY`
        );

        await connection.close();

        res.json({
            success: true,
            message: 'Berhasil terhubung ke Oracle',
            data: result.rows,
        });
    } catch (error) {
        console.error(error);

        res.status(500).json({
            success: false,
            message: 'Gagal terhubung ke Oracle',
            error: error.message,
        });
    }
});

// ========================================
// LOGIN
// ========================================

app.post('/api/login', async (req, res) => {
    const { stambuk, password } = req.body;

    // Validasi input
    if (!stambuk || !password) {
        return res.status(400).json({
            success: false,
            message: 'stambuk dan password wajib diisi',
        });
    }

    let connection;

    try {
        connection = await getConnection();

        const result = await connection.execute(
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
            {
                stambuk: stambuk,
                password: password,
            },
            {
                outFormat: require('oracledb').OUT_FORMAT_OBJECT,
            }
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'stambuk atau password salah',
            });
        }

        const user = result.rows[0];

        // ========================================
        // CEK STATUS USER
        // ========================================

        if (user.AKTIF !== 1) {
            return res.status(403).json({
                success: false,
                message: 'Akun tidak aktif',
            });
        }

        // ========================================
        // RESPONSE
        // ========================================

        return res.json({
            success: true,
            message: 'Login berhasil',
            user: user,
        });

    } catch (error) {
        console.error('Oracle Login Error:', error);

        return res.status(500).json({
            success: false,
            message: 'Terjadi kesalahan pada server',
        });

    } finally {
        if (connection) {
            try {
                await connection.close();
            } catch (error) {
                console.error('Error closing Oracle connection:', error);
            }
        }
    }
});

app.get('/api/kantor', async (req, res) => {
    let connection;

    try {
        connection = await getConnection();

        const result = await connection.execute(
            `
            SELECT
                KODE_KANTOR,
                NAMA_KANTOR,
                ALAMAT_KANTOR,
                EMAIL,
                PIC,
                KET_KANTOR,
                NO_SURAT,
                BOX,
                ZONA,
                LATITUDE,
                LONGITUDE,
                DISTANCE
            FROM DATA_KANTOR
            `,
            {},
            {
                outFormat: require('oracledb').OUT_FORMAT_OBJECT,
            }
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
            try {
                await connection.close();
            } catch (error) {
                console.error('Error closing Oracle connection:', error);
            }
        }
    }
});

// ========================================
// START SERVER
// ========================================

app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
});