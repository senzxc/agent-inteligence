const oracledb = require('oracledb');

const dbConfig = {
    user: 'SYARIAH4',
    password: 'syariah4',
    connectString: '10.10.10.21:1521/AJSB'
};

async function testConnection() {
    let connection;

    try {
        console.log('Mencoba terhubung ke Oracle...');

        connection = await oracledb.getConnection(dbConfig);

        console.log('✅ Berhasil terhubung ke Oracle!');

        const result = await connection.execute(
            `SELECT SYSDATE FROM DUAL`
        );

        console.log('Waktu Oracle:', result.rows[0][0]);

    } catch (error) {
        console.error('❌ Gagal terhubung ke Oracle:');
        console.error(error);

    } finally {
        if (connection) {
            try {
                await connection.close();
                console.log('Koneksi Oracle ditutup.');
            } catch (error) {
                console.error('Gagal menutup koneksi:', error);
            }
        }
    }
}

testConnection();