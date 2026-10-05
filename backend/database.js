const oracledb = require('oracledb');
require('dotenv').config();

const dbConfig = {
    user: process.env.ORACLE_USER,
    password: process.env.ORACLE_PASSWORD,
    connectString: process.env.ORACLE_CONNECT_STRING,
};

async function getConnection() {
    return await oracledb.getConnection(dbConfig);
}

module.exports = {
    getConnection,
};