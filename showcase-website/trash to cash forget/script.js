// ==============================================
// 🔑 Forgot Password - Trash To Cash
// ==============================================

const db = firebase.firestore();

const sendBtn = document.getElementById('sendResetBtn');
const emailInput = document.getElementById('resetEmail');
const messageDiv = document.getElementById('message');

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

function generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

async function storeOTP(email, otp) {
    try {
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        if (!userSnap.empty) {
            await db.collection('users').doc(userSnap.docs[0].id).set({
                otp: otp,
                otpExpiry: firebase.firestore.FieldValue.serverTimestamp(),
                otpAttempts: 0
            }, { merge: true });
            console.log('✅ OTP stored in users');
            return true;
        }

        const empSnap = await db.collection('employees').where('email', '==', email).limit(1).get();
        if (!empSnap.empty) {
            await db.collection('employees').doc(empSnap.docs[0].id).set({
                otp: otp,
                otpExpiry: firebase.firestore.FieldValue.serverTimestamp(),
                otpAttempts: 0
            }, { merge: true });
            console.log('✅ OTP stored in employees');
            return true;
        }

        console.log('❌ Email not found');
        return false;
    } catch (error) {
        console.error('Store OTP error:', error);
        return false;
    }
}

async function sendOTPEmail(email, otp) {
    try {
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
        console.log('📧 EmailJS status:', response.status);
        return response.status === 200;
    } catch (error) {
        console.error('Send OTP error:', error);
        return false;
    }
}

sendBtn.addEventListener('click', async () => {
    const email = emailInput.value.trim();

    if (!email) {
        showMessage('❌ Please enter your email address.', true);
        return;
    }

    sendBtn.disabled = true;
    sendBtn.textContent = 'Sending...';

    try {
        const otp = generateOTP();
        console.log('🔢 OTP generated:', otp);

        const stored = await storeOTP(email, otp);
        if (!stored) {
            showMessage('❌ No account found with this email.', true);
            sendBtn.disabled = false;
            sendBtn.textContent = 'Send OTP Code';
            return;
        }

        const sent = await sendOTPEmail(email, otp);
        if (!sent) {
            showMessage('❌ Failed to send OTP. Please try again.', true);
            sendBtn.disabled = false;
            sendBtn.textContent = 'Send OTP Code';
            return;
        }

        showMessage('✅ OTP sent to your email! Redirecting...', false);

        setTimeout(() => {
            window.location.href = '../trash to cash otp/index.html?email=' + encodeURIComponent(email);
        }, 1500);

    } catch (error) {
        console.error('Error:', error);
        showMessage('❌ An error occurred. Please try again.', true);
    } finally {
        sendBtn.disabled = false;
        sendBtn.textContent = 'Send OTP Code';
    }
});