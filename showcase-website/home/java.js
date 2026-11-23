// ==============================================
// 🏠 Home Page - Trash To Cash
// ==============================================

const firebaseConfig = {
    apiKey: "AIzaSyA3SRnpVHvmjDdqEjLIKl9j0ZypiAMgNUA",
    authDomain: "cach-6ebd3.firebaseapp.com",
    projectId: "cach-6ebd3",
    storageBucket: "cach-6ebd3.firebasestorage.app",
    messagingSenderId: "379255642460",
    appId: "1:379255642460:web:7540f30dbf9f48893c4999"
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
const auth = firebase.auth();

document.addEventListener('DOMContentLoaded', function() {

    // ========== SCROLL SPY ==========
    const navLinks = document.querySelectorAll('nav ul li a');
    const sections = document.querySelectorAll('section[id], .hero');

    function updateActiveNav() {
        let currentSection = 'home';
        const scrollPos = window.scrollY + 120;

        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const sectionId = section.getAttribute('id') || 'home';
            if (scrollPos >= sectionTop && scrollPos < sectionTop + sectionHeight) {
                currentSection = sectionId;
            }
        });

        navLinks.forEach(link => {
            link.classList.remove('active');
            if ((currentSection === 'home' && link.getAttribute('href') === '#') ||
                link.getAttribute('href') === '#' + currentSection) {
                link.classList.add('active');
            }
        });
    }

    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            const targetId = this.getAttribute('href');
            if (targetId === '#') return;
            e.preventDefault();
            const target = document.querySelector(targetId);
            if (target) target.scrollIntoView({ behavior: 'smooth' });
        });
    });

    let scrollTimeout;
    window.addEventListener('scroll', () => {
        if (scrollTimeout) clearTimeout(scrollTimeout);
        scrollTimeout = setTimeout(updateActiveNav, 50);
    });
    updateActiveNav();

    // ========== AUTH STATE ==========
    const profileDropdown = document.getElementById('profileDropdown');
    const profileAvatar = document.getElementById('profileAvatar');
    const profileImage = document.getElementById('profileImage');
    const profileInitial = document.getElementById('profileInitial');
    const dropdownMenu = document.getElementById('dropdownMenu');
    const loginBtn = document.getElementById('loginBtn');
    const dropdownName = document.getElementById('dropdownName');
    const dropdownEmail = document.getElementById('dropdownEmail');
    const dropdownLogoutBtn = document.getElementById('dropdownLogout');
    const dropdownProfileBtn = document.getElementById('dropdownProfile');
    const dropdownOrdersBtn = document.getElementById('dropdownOrders');
    const profileModal = document.getElementById('profileModal');
    const ordersModal = document.getElementById('ordersModal');
    const closeProfileModalBtn = document.getElementById('closeProfileModal');
    const closeOrdersModalBtn = document.getElementById('closeOrdersModal');
    const profileContent = document.getElementById('profileContent');
    const ordersContent = document.getElementById('ordersContent');

    // Toggle dropdown
    if (profileAvatar) {
        profileAvatar.addEventListener('click', (e) => {
            e.stopPropagation();
            dropdownMenu.classList.toggle('show');
        });
    }

    document.addEventListener('click', (e) => {
        if (profileDropdown && !profileDropdown.contains(e.target)) {
            dropdownMenu.classList.remove('show');
        }
    });

    // Auth state
    auth.onAuthStateChanged(async user => {
        if (user) {
            if (loginBtn) loginBtn.style.display = 'none';
            if (profileDropdown) profileDropdown.style.display = 'block';
            
            const name = user.displayName || user.email.split('@')[0];
            if (dropdownName) dropdownName.textContent = name;
            if (dropdownEmail) dropdownEmail.textContent = user.email;
            
            try {
                const userDoc = await db.collection('users').doc(user.uid).get();
                if (userDoc.exists) {
                    const data = userDoc.data();
                    const photoURL = data.profileImage || '';
                    
                    if (photoURL && profileImage) {
                        profileImage.src = photoURL;
                        profileImage.style.display = 'block';
                        if (profileInitial) profileInitial.style.display = 'none';
                    } else {
                        if (profileImage) profileImage.style.display = 'none';
                        if (profileInitial) {
                            profileInitial.style.display = 'block';
                            profileInitial.textContent = name.charAt(0).toUpperCase();
                        }
                    }
                }
            } catch (e) {
                console.log('Error:', e);
                if (profileInitial) profileInitial.textContent = name.charAt(0).toUpperCase();
            }
        } else {
            if (loginBtn) loginBtn.style.display = 'inline-block';
            if (profileDropdown) profileDropdown.style.display = 'none';
        }
    });

    // Logout
    if (dropdownLogoutBtn) {
        dropdownLogoutBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            if (dropdownMenu) dropdownMenu.classList.remove('show');
            await auth.signOut();
            window.location.reload();
        });
    }

    // ========== MY PROFILE ==========
    if (dropdownProfileBtn) {
        dropdownProfileBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            if (dropdownMenu) dropdownMenu.classList.remove('show');
            
            const user = auth.currentUser;
            if (!user) {
                alert('Please sign in first.');
                return;
            }
            
            if (profileContent) profileContent.innerHTML = '<div class="spinner"></div><p>Loading...</p>';
            if (profileModal) profileModal.style.display = 'flex';
            
            try {
                const userDoc = await db.collection('users').doc(user.uid).get();
                if (userDoc.exists) {
                    const data = userDoc.data();
                    const photoURL = data.profileImage || '';
                    const avatarHTML = photoURL 
                        ? `<img src="${photoURL}" alt="Profile" style="width:100px;height:100px;border-radius:50%;object-fit:cover;margin:0 auto;display:block;">`
                        : `<div style="width:100px;height:100px;border-radius:50%;background:linear-gradient(135deg,#00C76A,#008a4a);color:white;font-size:40px;display:flex;align-items:center;justify-content:center;margin:0 auto;font-weight:700;">${(data.firstName||user.email||'U').charAt(0).toUpperCase()}</div>`;
                    
                    if (profileContent) {
                        profileContent.innerHTML = `
                            ${avatarHTML}
                            <h4 style="margin-top:16px;">${data.firstName || ''} ${data.lastName || ''}</h4>
                            <p style="color:#888;">${data.displayId || ''}</p>
                            <p>📧 ${data.email || user.email}</p>
                            <p>📱 ${data.phone || '-'}</p>
                            <p>⭐ <strong>${data.points || 0}</strong> points</p>
                            <p>🔄 ${data.totalScans || 0} scans</p>
                            <p>📦 ${data.totalItems || 0} items</p>
                        `;
                    }
                } else {
                    if (profileContent) profileContent.innerHTML = '<p>No profile data found.</p>';
                }
            } catch (e) {
                if (profileContent) profileContent.innerHTML = '<p>Error loading profile.</p>';
            }
        });
    }

    // Close Profile Modal
    if (closeProfileModalBtn) {
        closeProfileModalBtn.addEventListener('click', () => {
            if (profileModal) profileModal.style.display = 'none';
        });
    }

    if (profileModal) {
        profileModal.addEventListener('click', function(e) {
            if (e.target === profileModal) profileModal.style.display = 'none';
        });
    }

    // ========== MY ORDERS ==========
    if (dropdownOrdersBtn) {
        dropdownOrdersBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            if (dropdownMenu) dropdownMenu.classList.remove('show');
            
            const user = auth.currentUser;
            if (!user) {
                alert('Please sign in first.');
                return;
            }
            
            if (ordersContent) ordersContent.innerHTML = '<div class="spinner"></div><p>Loading...</p>';
            if (ordersModal) ordersModal.style.display = 'flex';
            
            try {
                const snap = await db.collection('shop_orders')
                    .where('userId', '==', user.uid)
                    .orderBy('createdAt', 'desc')
                    .limit(20)
                    .get();
                
                if (snap.empty) {
                    const snap2 = await db.collection('shop_orders')
                        .where('userEmail', '==', user.email)
                        .orderBy('createdAt', 'desc')
                        .limit(20)
                        .get();
                    
                    if (snap2.empty) {
                        if (ordersContent) ordersContent.innerHTML = '<p style="text-align:center;color:#888;">No orders found.</p>';
                        return;
                    }
                    
                    let html = '';
                    snap2.forEach(doc => {
                        const order = doc.data();
                        const date = order.createdAt?.toDate ? order.createdAt.toDate().toLocaleDateString('en-GB') : 'N/A';
                        const badge = order.status === 'completed' ? '🟢 Completed' : order.status === 'cancelled' ? '🔴 Cancelled' : '🟡 Pending';
                        
                        html += `
                            <div style="background:#f9f9f9;padding:15px;border-radius:12px;margin-bottom:10px;">
                                <h4>${order.material || '-'}</h4>
                                <p>Quantity: ${order.quantityKg || 0} kg | Total: ${order.totalPrice || 0} EGP</p>
                                <p>Status: ${badge}</p>
                                <p style="font-size:12px;color:#888;">Date: ${date}</p>
                            </div>
                        `;
                    });
                    
                    if (ordersContent) ordersContent.innerHTML = html;
                    return;
                }
                
                let html = '';
                snap.forEach(doc => {
                    const order = doc.data();
                    const date = order.createdAt?.toDate ? order.createdAt.toDate().toLocaleDateString('en-GB') : 'N/A';
                    const badge = order.status === 'completed' ? '🟢 Completed' : order.status === 'cancelled' ? '🔴 Cancelled' : '🟡 Pending';
                    
                    html += `
                        <div style="background:#f9f9f9;padding:15px;border-radius:12px;margin-bottom:10px;">
                            <h4>${order.material || '-'}</h4>
                            <p>Quantity: ${order.quantityKg || 0} kg | Total: ${order.totalPrice || 0} EGP</p>
                            <p>Status: ${badge}</p>
                            <p style="font-size:12px;color:#888;">Date: ${date}</p>
                        </div>
                    `;
                });
                
                if (ordersContent) ordersContent.innerHTML = html;
            } catch (e) {
                console.error('Error:', e);
                if (ordersContent) ordersContent.innerHTML = '<p>Error loading orders. Please try again.</p>';
            }
        });
    }

    // Close Orders Modal
    if (closeOrdersModalBtn) {
        closeOrdersModalBtn.addEventListener('click', () => {
            if (ordersModal) ordersModal.style.display = 'none';
        });
    }

    if (ordersModal) {
        ordersModal.addEventListener('click', function(e) {
            if (e.target === ordersModal) ordersModal.style.display = 'none';
        });
    }

    // ========== SHOP ==========
    window.openOrderForm = function(material, pricePerTon) {
        const kg = prompt(`How many kg of ${material} do you want to sell?\n\nPrice: ${pricePerTon} EGP per Ton (${(pricePerTon/1000).toFixed(0)} EGP per kg)`);
        
        if (!kg || isNaN(kg) || kg <= 0) {
            alert('❌ Please enter a valid quantity.');
            return;
        }
        
        const phone = prompt('Enter your phone number for contact:');
        
        if (!phone) {
            alert('❌ Please enter your phone number.');
            return;
        }
        
        const totalPrice = (kg * pricePerTon / 1000).toFixed(2);
        const confirmMsg = `📋 Order Summary:\n\nMaterial: ${material}\nQuantity: ${kg} kg\nPrice per Ton: ${pricePerTon} EGP\nTotal: ${totalPrice} EGP\nPhone: ${phone}\n\nConfirm order?`;
        
        if (confirm(confirmMsg)) {
            submitOrder(material, kg, pricePerTon, totalPrice, phone);
        }
    };

    async function submitOrder(material, kg, pricePerTon, totalPrice, phone) {
        try {
            const user = auth.currentUser;
            await db.collection('shop_orders').add({
                material: material,
                quantityKg: Number(kg),
                pricePerTon: pricePerTon,
                totalPrice: Number(totalPrice),
                phone: phone,
                userId: user ? user.uid : '',
                userEmail: user ? user.email : '',
                status: 'pending',
                createdAt: firebase.firestore.FieldValue.serverTimestamp()
            });
            
            alert(`✅ Order submitted successfully!\n\nMaterial: ${material}\nQuantity: ${kg} kg\nTotal: ${totalPrice} EGP\n\nWe will contact you at ${phone} soon.`);
        } catch (error) {
            console.error('Order error:', error);
            alert('❌ Failed to submit order. Please try again.');
        }
    }

    // ========== CONTACT ==========
    const contactBtn = document.querySelector('.contact-form button');
    if (contactBtn) {
        contactBtn.addEventListener('click', async function(e) {
            e.preventDefault();
            
            const inputs = document.querySelectorAll('.contact-form input, .contact-form textarea');
            const firstName = inputs[0].value.trim();
            const lastName = inputs[1].value.trim();
            const phone = inputs[2].value.trim();
            const email = inputs[3].value.trim();
            const message = inputs[4].value.trim();
            
            if (!firstName || !phone) {
                alert('❌ Please fill at least your name and phone number.');
                return;
            }
            
            try {
                await db.collection('contact_messages').add({
                    firstName: firstName,
                    lastName: lastName,
                    phone: phone,
                    email: email,
                    message: message,
                    status: 'unread',
                    createdAt: firebase.firestore.FieldValue.serverTimestamp()
                });
                
                alert('✅ Message sent successfully! We will contact you soon.');
                inputs.forEach(input => input.value = '');
            } catch (error) {
                console.error('Contact error:', error);
                alert('❌ Failed to send message. Please try again.');
            }
        });
    }

});