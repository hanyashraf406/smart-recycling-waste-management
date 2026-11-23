// ==============================================
// 🔢 OTP Verification - Trash To Cash
// ==============================================

const db = firebase.firestore();

const verifyBtn = document.getElementById('verifyOtpBtn');
const resendOtp = document.getElementById('resendOtp');
const messageDiv = document.getElementById('message');
const otpInputs = document.querySelectorAll('.otp-input');

// Get email from URL
const urlParams = new URLSearchParams(window.location.search);
const email = urlParams.get('email') || '';
console.log('📧 Email:', email);

// EmailJS Config
const EMAILJS_SERVICE_ID = 'service_k3yt6hr';
const EMAILJS_TEMPLATE_ID = 'template_zp5xiii';
const EMAILJS_PUBLIC_KEY = 'agiSTZip5wWyIRDzX';
const EMAILJS_PRIVATE_KEY = 'RbmNT8IlUzgFBqCIAe8xz';

function showMessage(text, isError = false) {
    messageDiv.textContent = text;
    messageDiv.style.display = 'block';
    messageDiv.style.color = isError ? '#e74c3c' : '#27ae60';
    messageDiv.style.background = isError ? '#fdecea' : '#e8f8f0';
}

// Auto-focus next input
otpInputs.forEach((input, index) => {
    input.addEventListener('input', (e) => {
        if (e.target.value && index < 5) {
            otpInputs[index + 1].focus();
        }
    });
    input.addEventListener('keydown', (e) => {
        if (e.key === 'Backspace' && !e.target.value && index > 0) {
            otpInputs[index - 1].focus();
        }
    });
});

// Verify OTP
async function verifyOTP(email, otp) {
    try {
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        const empSnap = await db.collection('employees').where('email', '==', email).limit(1).get();

        let data = null;
        if (!userSnap.empty) {
            data = userSnap.docs[0].data();
            console.log('📧 Found in users');
        }
        if (!empSnap.empty) {
            data = empSnap.docs[0].data();
            console.log('📧 Found in employees');
        }

        if (!data) {
            console.log('❌ Email not found');
            return false;
        }

        const storedOTP = data.otp;
        const attempts = data.otpAttempts || 0;
        const expiry = data.otpExpiry ? data.otpExpiry.toDate() : null;

        console.log('🔢 Stored OTP:', storedOTP);
        console.log('🔢 Entered OTP:', otp);
        console.log('🔢 Attempts:', attempts);

        if (attempts >= 5) {
            console.log('❌ Too many attempts');
            return false;
        }

        if (expiry && (new Date() - expiry) > 5 * 60 * 1000) {
            console.log('❌ OTP expired');
            return false;
        }

        return storedOTP === otp;
    } catch (error) {
        console.error('Verify error:', error);
        return false;
    }
}

// Handle Verify OTP
verifyBtn.addEventListener('click', async () => {
    const otp = Array.from(otpInputs).map(input => input.value).join('');

    if (otp.length !== 6) {
        showMessage('❌ Please enter the 6-digit OTP.', true);
        return;
    }

    verifyBtn.disabled = true;
    verifyBtn.textContent = 'Verifying...';

    const isValid = await verifyOTP(email, otp);

    if (isValid) {
        showMessage('✅ OTP verified! Redirecting...', false);
        setTimeout(() => {
            window.location.href = '../trash to cash reset/index.html?email=' + encodeURIComponent(email);
        }, 1000);
    } else {
        showMessage('❌ Invalid or expired OTP.', true);
    }

    verifyBtn.disabled = false;
    verifyBtn.textContent = 'Verify OTP';
});

// Resend OTP
resendOtp.addEventListener('click', async (e) => {
    e.preventDefault();

    if (!email) {
        showMessage('❌ Email not found.', true);
        return;
    }

    resendOtp.textContent = 'Sending...';
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    try {
        // Store new OTP
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        if (!userSnap.empty) {
            await db.collection('users').doc(userSnap.docs[0].id).update({
                otp: otp,
                otpExpiry: firebase.firestore.FieldValue.serverTimestamp(),
                otpAttempts: 0
            });
        }

        // Send OTP
        const response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                service_id: EMAILJS_SERVICE_ID,
                template_id: EMAILJS_TEMPLATE_ID,
                user_id: EMAILJS_PUBLIC_KEY,
                accessToken: EMAILJS_PRIVATE_KEY,
                template_params: {
                    otp: otp,
                    to_email: email
                }
            })
        });

        if (response.status === 200) {
            showMessage('✅ New OTP sent!', false);
        } else {
            showMessage('❌ Failed to send OTP.', true);
        }
    } catch (error) {
        showMessage('❌ Error. Try again.', true);
    } finally {
        resendOtp.textContent = 'Resend OTP';
    }
});