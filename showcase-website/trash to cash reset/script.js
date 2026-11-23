// ==============================================
// 🔒 Reset Password - Trash To Cash
// ==============================================

const resetBtn = document.getElementById('resetBtn');
const messageDiv = document.getElementById('message');
const newPasswordInput = document.getElementById('newPassword');
const confirmPasswordInput = document.getElementById('confirmPassword');

// Get email from URL
const urlParams = new URLSearchParams(window.location.search);
const email = urlParams.get('email') || '';
console.log('📧 Email:', email);

// Toggle password visibility
document.getElementById('toggleNew').addEventListener('click', function() {
    const type = newPasswordInput.type === 'password' ? 'text' : 'password';
    newPasswordInput.type = type;
    this.classList.toggle('fa-eye');
    this.classList.toggle('fa-eye-slash');
});

document.getElementById('toggleConfirm').addEventListener('click', function() {
    const type = confirmPasswordInput.type === 'password' ? 'text' : 'password';
    confirmPasswordInput.type = type;
    this.classList.toggle('fa-eye');
    this.classList.toggle('fa-eye-slash');
});

function showMessage(text, isError = false) {
    messageDiv.textContent = text;
    messageDiv.style.display = 'block';
    messageDiv.style.color = isError ? '#e74c3c' : '#27ae60';
    messageDiv.style.background = isError ? '#fdecea' : '#e8f8f0';
}

resetBtn.addEventListener('click', async () => {
    const newPassword = newPasswordInput.value;
    const confirmPassword = confirmPasswordInput.value;

    if (!newPassword || !confirmPassword) {
        showMessage('❌ Please fill all fields.', true);
        return;
    }

    if (newPassword.length < 6) {
        showMessage('❌ Password must be at least 6 characters.', true);
        return;
    }

    if (newPassword !== confirmPassword) {
        showMessage('❌ Passwords do not match.', true);
        return;
    }

    if (!email) {
        showMessage('❌ Email not found. Please try again.', true);
        return;
    }

    resetBtn.disabled = true;
    resetBtn.textContent = 'Resetting...';

    try {
        const response = await fetch('https://us-central1-cach-6ebd3.cloudfunctions.net/resetPasswordV2', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                data: {
                    email: email,
                    newPassword: newPassword
                }
            })
        });

        const result = await response.json();
        console.log('✅ Result:', result);

        if (result.result && result.result.success) {
            showMessage('✅ Password changed! Redirecting to Sign In...', false);
            setTimeout(() => {
                window.location.href = '../trash to cash sign in/index.html';
            }, 2000);
        } else {
            const errorMsg = result.error ? result.error.message : 'Failed to reset password';
            showMessage('❌ ' + errorMsg, true);
        }
    } catch (error) {
        console.error('❌ Error:', error);
        showMessage('❌ Network error. Please try again.', true);
    } finally {
        resetBtn.disabled = false;
        resetBtn.textContent = 'Reset Password';
    }
});