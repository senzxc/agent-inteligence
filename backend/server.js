const express = require('express');

const app = express();
const PORT = 3000;

// Middleware untuk membaca JSON
app.use(express.json());

// Route sederhana untuk testing
app.get('/', (req, res) => {
    res.json({
        message: 'Backend Agent Intelligence Tracker berhasil berjalan!'
    });
});

// Jalankan server
app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
});