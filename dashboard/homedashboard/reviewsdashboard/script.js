import { db } from "../../firebase-config.js";
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  updateDoc
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

// ✅ قراءة بيانات الأدمن
const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';

console.log('👤 Role:', adminData.role, '| 🏭 Warehouse:', adminWarehouseId);

// ========== DOM Elements - Reviews ==========
const reviewsGrid = document.getElementById("reviewsGrid");
const searchReviews = document.getElementById("searchReviews");
const ratingFilter = document.getElementById("ratingFilter");
const sentimentFilter = document.getElementById("sentimentFilter");
const clearFiltersButton = document.getElementById("clearFiltersButton");
const totalReviews = document.getElementById("totalReviews");
const positiveReviews = document.getElementById("positiveReviews");
const negativeReviews = document.getElementById("negativeReviews");
const averageRating = document.getElementById("averageRating");
const chartContext = document.getElementById("reviewsChart");

// ========== DOM Elements - Messages ==========
const msgSearch = document.getElementById("msgSearch");
const msgStatusFilter = document.getElementById("msgStatusFilter");
const msgClearFiltersBtn = document.getElementById("msgClearFilters");
const msgRefreshBtn = document.getElementById("msgRefreshBtn");
const msgResultCount = document.getElementById("msgResultCount");
const msgTableBody = document.getElementById("msgTableBody");

let reviews = [];
let allMessages = [];
let filters = { search: "", rating: "all", sentiment: "all" };
let reviewsChart = null;

// ========== HELPERS ==========
function normalizeText(value) {
  return String(value || "").trim().toLowerCase();
}

function sentimentFromRating(rating) {
  return Number(rating) >= 4 ? "positive" : "negative";
}

function formatDate(value) {
  if (value?.toDate) return value.toDate().toLocaleString();
  if (value?._seconds) return new Date(value._seconds * 1000).toLocaleString();
  if (value?.seconds) return new Date(value.seconds * 1000).toLocaleString();
  if (typeof value === "string" && value.trim()) return value;
  return new Date().toLocaleString();
}

// ========== TABS ==========
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', function() {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    this.classList.add('active');
    document.getElementById('tab-' + this.dataset.tab).classList.add('active');
    if (this.dataset.tab === 'messages') loadMessages();
  });
});

// ========== REVIEWS ==========
function computeVisibleReviews() {
  return reviews.filter((review) => {
    const matchesSearch = !filters.search || [review.userName, review.userEmail, review.comment]
      .join(" ").toLowerCase().includes(filters.search);
    const matchesRating = filters.rating === "all" || String(review.rating) === filters.rating;
    const matchesSentiment = filters.sentiment === "all" || sentimentFromRating(review.rating) === filters.sentiment;
    return matchesSearch && matchesRating && matchesSentiment;
  });
}

function updateSummary() {
  const completedReviews = reviews.filter(r => r.status === 'completed' && r.rating > 0);
  totalReviews.textContent = String(completedReviews.length);
  positiveReviews.textContent = String(completedReviews.filter((r) => sentimentFromRating(r.rating) === "positive").length);
  negativeReviews.textContent = String(completedReviews.filter((r) => sentimentFromRating(r.rating) === "negative").length);
  const totalScore = completedReviews.reduce((sum, r) => sum + Number(r.rating || 0), 0);
  const average = completedReviews.length ? (totalScore / completedReviews.length).toFixed(1) : "0.0";
  averageRating.textContent = average;

  if (!reviewsChart) {
    reviewsChart = new Chart(chartContext, {
      type: "bar",
      data: {
        labels: ["Positive", "Negative"],
        datasets: [{
          label: "Reviews",
          data: [0, 0],
          backgroundColor: ["#00C76A", "#FF5252"],
          borderRadius: 12
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
      }
    });
  }

  reviewsChart.data.datasets[0].data = [
    completedReviews.filter((r) => sentimentFromRating(r.rating) === "positive").length,
    completedReviews.filter((r) => sentimentFromRating(r.rating) === "negative").length
  ];
  reviewsChart.update();
}

function renderReviews() {
  const visibleReviews = computeVisibleReviews();
  updateSummary();

  if (!visibleReviews.length) {
    reviewsGrid.innerHTML = '<div class="empty-state">No reviews match the current filters.</div>';
    return;
  }

  reviewsGrid.innerHTML = visibleReviews.map((review) => {
    const sentiment = sentimentFromRating(review.rating);
    const stars = "⭐".repeat(Number(review.rating) || 0);
    const userName = review.userName || review.name || review.userEmail?.split('@')[0] || 'Anonymous';
    const userEmail = review.userEmail || review.email || '-';
    const userDisplayId = review.userDisplayId || '';
    const employeeDisplayId = review.employeeDisplayId || '';
    const employeeEmail = review.employeeEmail || '';
    const processId = review.processId || '';
    const pointsEarned = review.pointsEarned || 0;

    return `
      <article class="review-card ${sentiment}">
        <div class="review-header">
          <div class="review-avatar">${userName.charAt(0).toUpperCase()}</div>
          <div class="review-info">
            <div class="review-name">
              ${userName}
              ${userDisplayId ? `<span style="font-size:12px;color:#00C76A;font-weight:600;">(${userDisplayId})</span>` : ''}
            </div>
            <div class="review-email">${userEmail}</div>
            ${employeeDisplayId ? `<div style="font-size:11px;color:#8A8A98;">Employee: ${employeeDisplayId} (${employeeEmail || 'N/A'})</div>` : ''}
            ${processId ? `<div style="font-size:11px;color:#8A8A98;">Process: ${processId}</div>` : ''}
            ${pointsEarned > 0 ? `<div style="font-size:11px;color:#FF9800;">Points earned: ${pointsEarned}</div>` : ''}
          </div>
        </div>
        <div class="review-rating">${stars}</div>
        <p class="review-comment">${review.comment || 'No comment'}</p>
        <div class="review-footer">
          <span class="review-date">${formatDate(review.createdAt)}</span>
          <button class="delete-review" data-delete-review="${review.id}">🗑️ Delete</button>
        </div>
      </article>
    `;
  }).join("");
}

function resetFilters() {
  filters = { search: "", rating: "all", sentiment: "all" };
  searchReviews.value = "";
  ratingFilter.value = "all";
  sentimentFilter.value = "all";
  renderReviews();
}

async function handleDeleteReview(reviewId) {
  const confirmed = window.confirm("Delete this review?");
  if (!confirmed) return;
  try {
    await deleteDoc(doc(db, "reviews", reviewId));
    console.log('✅ Review deleted:', reviewId);
    await loadReviewsFromFirestore();
  } catch (error) {
    console.error('Error deleting review:', error);
    alert("Failed to delete review.");
  }
}

async function loadReviewsFromFirestore() {
  try {
    console.log('🔄 Loading reviews from Firestore...');
    let warehouseEmployeeIds = new Set();
    
    if (!isSuperAdmin && adminWarehouseId !== 'all') {
      const employeesSnap = await getDocs(query(
        collection(db, "employees"),
        where("warehouseId", "==", adminWarehouseId)
      ));
      employeesSnap.docs.forEach(doc => warehouseEmployeeIds.add(doc.id));
    }
    
    const reviewsSnap = await getDocs(query(
      collection(db, "reviews"),
      orderBy("createdAt", "desc"),
      limit(300)
    ));
    
    let allReviews = reviewsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log('📊 Total reviews:', allReviews.length);
    
    allReviews = allReviews.filter(r => {
      const status = (r.status || '').toLowerCase();
      return status === 'completed' || status === 'done';
    });
    
    if (!isSuperAdmin && adminWarehouseId !== 'all') {
      allReviews = allReviews.filter(r => {
        if (r.employeeId && warehouseEmployeeIds.has(r.employeeId)) return true;
        if (r.warehouseId === adminWarehouseId) return true;
        return false;
      });
    }
    
    reviews = allReviews;
    console.log('✅ Final reviews:', reviews.length);
    renderReviews();
  } catch (error) {
    console.error('❌ Failed to load reviews:', error);
    reviewsGrid.innerHTML = '<div class="empty-state">Failed to load reviews. Check console.</div>';
  }
}

// ========== REVIEWS EVENTS ==========
searchReviews.addEventListener("input", () => {
  filters.search = normalizeText(searchReviews.value);
  renderReviews();
});

ratingFilter.addEventListener("change", () => {
  filters.rating = ratingFilter.value;
  renderReviews();
});

sentimentFilter.addEventListener("change", () => {
  filters.sentiment = sentimentFilter.value;
  renderReviews();
});

clearFiltersButton.addEventListener("click", resetFilters);

reviewsGrid.addEventListener("click", (event) => {
  const deleteButton = event.target.closest("[data-delete-review]");
  if (!deleteButton) return;
  handleDeleteReview(deleteButton.dataset.deleteReview);
});

// ========== MESSAGES ==========
async function loadMessages() {
  try {
    msgResultCount.textContent = "Loading messages...";
    msgTableBody.innerHTML = '<tr><td colspan="7" class="empty-state">Loading messages...</td></tr>';
    
    const snap = await getDocs(query(
      collection(db, "contact_messages"),
      orderBy("createdAt", "desc")
    ));
    
    allMessages = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log('📧 Messages loaded:', allMessages.length);
    renderMessages();
  } catch (error) {
    console.error('❌ Failed to load messages:', error);
    msgTableBody.innerHTML = '<tr><td colspan="7" class="empty-state">❌ Failed to load messages.</td></tr>';
  }
}

function getFilteredMessages() {
  const searchTerm = msgSearch.value.trim().toLowerCase();
  const statusTerm = msgStatusFilter.value;

  return allMessages.filter(message => {
    const matchesSearch = !searchTerm || [
      message.firstName, message.lastName, message.email, message.phone, message.message
    ].join(" ").toLowerCase().includes(searchTerm);

    const matchesStatus = statusTerm === "all" || message.status === statusTerm;

    return matchesSearch && matchesStatus;
  });
}

function renderMessages() {
  const filtered = getFilteredMessages();
  msgTableBody.innerHTML = "";

  if (filtered.length === 0) {
    msgTableBody.innerHTML = '<tr><td colspan="7" class="empty-state">No messages found.</td></tr>';
    msgResultCount.textContent = allMessages.length ? "No results for the selected filters." : "Waiting for messages...";
    return;
  }

  filtered.forEach(message => {
    let badgeClass, badgeText;
    
    switch (message.status) {
      case 'read':
        badgeClass = 'badge completed';
        badgeText = 'Read';
        break;
      case 'replied':
        badgeClass = 'badge completed';
        badgeText = 'Replied';
        break;
      default:
        badgeClass = 'badge pending';
        badgeText = 'Unread';
    }

    const date = message.createdAt?.toDate 
      ? message.createdAt.toDate().toLocaleDateString('en-GB') 
      : (message.createdAt?._seconds 
        ? new Date(message.createdAt._seconds * 1000).toLocaleDateString('en-GB') 
        : 'N/A');

    const name = `${message.firstName || ''} ${message.lastName || ''}`.trim() || '-';
    
    const actions = `
      <button class="row-action confirm-btn" data-msg-read="${message.id}">✅ Read</button>
      <button class="row-action reject-btn" data-msg-delete="${message.id}">🗑️ Delete</button>
    `;

    msgTableBody.insertAdjacentHTML("beforeend", `
      <tr>
        <td style="font-weight:600;">${name}</td>
        <td>${message.phone || '-'}</td>
        <td style="font-size:12px;">${message.email || '-'}</td>
        <td style="max-width:250px;font-size:13px;">${(message.message || '-').substring(0, 100)}</td>
        <td style="font-size:12px;">${date}</td>
        <td><span class="${badgeClass}">${badgeText}</span></td>
        <td style="display:flex;gap:6px;flex-wrap:wrap;">${actions}</td>
      </tr>
    `);
  });

  document.querySelectorAll('[data-msg-read]').forEach(btn => {
    btn.onclick = function() { markAsRead(this.dataset.msgRead); };
  });

  document.querySelectorAll('[data-msg-delete]').forEach(btn => {
    btn.onclick = function() { deleteMessage(this.dataset.msgDelete); };
  });

  msgResultCount.textContent = `Showing ${filtered.length} of ${allMessages.length} messages`;
}

async function markAsRead(messageId) {
  try {
    await updateDoc(doc(db, "contact_messages", messageId), { status: "read" });
    console.log('✅ Message marked as read:', messageId);
    loadMessages();
  } catch (error) {
    console.error('Error:', error);
  }
}

async function deleteMessage(messageId) {
  if (!confirm("Delete this message?")) return;
  try {
    await deleteDoc(doc(db, "contact_messages", messageId));
    console.log('✅ Message deleted:', messageId);
    loadMessages();
  } catch (error) {
    console.error('Error:', error);
  }
}

// ========== MESSAGES EVENTS ==========
msgSearch.addEventListener("input", renderMessages);
msgStatusFilter.addEventListener("change", renderMessages);
msgClearFiltersBtn.addEventListener("click", () => {
  msgSearch.value = "";
  msgStatusFilter.value = "all";
  renderMessages();
});
msgRefreshBtn.addEventListener("click", loadMessages);

// ========== INIT ==========
function updateUIBasedOnRole() {
  const label = document.querySelector('.admin-label') || document.querySelector('.admin-title');
  if (!label) return;
  if (isSuperAdmin) {
    label.textContent = '🔑 Super Admin - All Warehouses';
    label.style.color = '#00C76A';
  } else {
    label.textContent = `👤 Admin - ${adminData.warehouseName || 'Warehouse'}`;
    label.style.color = '#8A8A98';
  }
}

updateUIBasedOnRole();
loadReviewsFromFirestore();
setInterval(loadReviewsFromFirestore, 30000);

console.log('🚀 Reviews Dashboard Ready');