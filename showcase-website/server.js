// ==============================================
// 🚀 Trash To Cash - Node.js + Express Backend
// ==============================================

const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;

// ============================================
// Middleware
// ============================================

// Parse JSON requests
app.use(express.json());

// Parse URL-encoded form data
app.use(express.urlencoded({ extended: true }));

// ============================================
// Serve Static Files (HTML, CSS, JS, Images)
// ============================================

// --- Original Pages ---
app.use('/signin', express.static(path.join(__dirname, 'trash to cash sign in')));
app.use('/signup', express.static(path.join(__dirname, 'trash to cash sign up')));
app.use('/forgot', express.static(path.join(__dirname, 'trash to cash sign in', 'trash to cash forget')));

// --- Fixed2 Pages (New Design) - serve assets from root ---
app.use('/assets', express.static(path.join(__dirname, 'trash-to-cash-fixed2', 'assets')));

// Firebase config from root
app.use('/firebase-config.js', express.static(path.join(__dirname, 'firebase-config.js')));

// ============================================
// Routes
// ============================================

// Home → redirect to Sign In (new design)
app.get('/', (req, res) => {
    res.redirect('/signin2');
});

// --- Original Pages Routes ---
app.get('/signin', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash to cash sign in', 'index.html'));
});

app.get('/signup', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash to cash sign up', 'index.html'));
});

app.get('/forgot', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash to cash sign in', 'trash to cash forget', 'index.html'));
});

// --- Fixed2 Pages Routes (New Design) ---
app.get('/signin2', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash-to-cash-fixed2', 'index.html'));
});

app.get('/register', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash-to-cash-fixed2', 'register.html'));
});

app.get('/forgot2', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash-to-cash-fixed2', 'forget.html'));
});

app.get('/otp', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash-to-cash-fixed2', 'otp.html'));
});

app.get('/reset', (req, res) => {
    res.sendFile(path.join(__dirname, 'trash-to-cash-fixed2', 'reset.html'));
});

// ============================================
// API Endpoints
// ============================================

// Health check
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        message: '🚀 Trash To Cash server is running!',
        timestamp: new Date().toISOString()
    });
});

// ============================================
// Start Server
// ============================================

app.listen(PORT, () => {
    console.log('');
    console.log('🚀 =============================================');
    console.log('   Trash To Cash Server is Running!');
    console.log('   =============================================');
    console.log('');
    console.log('   📐 NEW DESIGN:');
    console.log(`   🔐 Sign In:         http://localhost:${PORT}/signin2`);
    console.log(`   📝 Register:        http://localhost:${PORT}/register`);
    console.log(`   🔑 Forgot Password: http://localhost:${PORT}/forgot2`);
    console.log(`   🔢 OTP:             http://localhost:${PORT}/otp`);
    console.log(`   🔄 Reset Password:  http://localhost:${PORT}/reset`);
    console.log('');
    console.log('   📁 ORIGINAL DESIGN:');
    console.log(`   🔐 Sign In:         http://localhost:${PORT}/signin`);
    console.log(`   📝 Sign Up:         http://localhost:${PORT}/signup`);
    console.log(`   🔑 Forgot:          http://localhost:${PORT}/forgot`);
    console.log('');
    console.log(`   💚 Health Check:    http://localhost:${PORT}/api/health`);
    console.log('');
    console.log('   =============================================');
    console.log('');
});
