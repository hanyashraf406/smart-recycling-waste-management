import { db } from "../../firebase-config.js";
import {
  collection,
  addDoc,
  deleteDoc,
  doc,
  getDocs,
  query,
  where,
  orderBy,
  Timestamp,
  serverTimestamp,
  updateDoc,
  writeBatch
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

// ✅ Read admin data from localStorage
const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';
const adminEmail = adminData.email || 'admin';

console.log('👤 Admin Role:', adminData.role);
console.log('🏭 Warehouse ID:', adminWarehouseId);
console.log('🔑 Is Super Admin:', isSuperAdmin);

// ✅ DOM Elements - Reports
const tableBody = document.getElementById("tableBody");
const searchInput = document.getElementById("search");
const statusFilter = document.getElementById("statusFilter");
const clearFiltersButton = document.getElementById("clearFilters");
const resultCount = document.getElementById("resultCount");
const dateRangeDisplay = document.getElementById("dateRangeDisplay");
const refreshBtn = document.getElementById("refreshBtn");
const dynamicMaterialCards = document.getElementById("dynamicMaterialCards");

const metricTotal = document.getElementById("metricTotal");
const metricCompleted = document.getElementById("metricCompleted");
const metricPending = document.getElementById("metricPending");
const metricIssues = document.getElementById("metricIssues");

// ✅ DOM Elements - Withdrawals
const wTableBody = document.getElementById("wTableBody");
const wSearchInput = document.getElementById("wSearch");
const wStatusFilter = document.getElementById("wStatusFilter");
const wClearFiltersBtn = document.getElementById("wClearFilters");
const wRefreshBtn = document.getElementById("wRefreshBtn");
const wDeleteAllBtn = document.getElementById("wDeleteAllBtn");
const wResultCount = document.getElementById("wResultCount");

const wMetricToday = document.getElementById("wMetricToday");
const wMetricAmount = document.getElementById("wMetricAmount");
const wMetricPending = document.getElementById("wMetricPending");
const wMetricCompleted = document.getElementById("wMetricCompleted");

const confirmModal = document.getElementById("confirmModal");
const confirmModalInfo = document.getElementById("confirmModalInfo");
const referenceInput = document.getElementById("referenceInput");
const confirmTransferBtn = document.getElementById("confirmTransferBtn");
const cancelConfirmBtn = document.getElementById("cancelConfirmBtn");

const rejectModal = document.getElementById("rejectModal");
const rejectModalInfo = document.getElementById("rejectModalInfo");
const rejectNotesInput = document.getElementById("rejectNotesInput");
const rejectTransferBtn = document.getElementById("rejectTransferBtn");
const cancelRejectBtn = document.getElementById("cancelRejectBtn");

// ✅ DOM Elements - Shop Orders
const soTableBody = document.getElementById("soTableBody");
const soSearchInput = document.getElementById("soSearch");
const soStatusFilter = document.getElementById("soStatusFilter");
const soClearFiltersBtn = document.getElementById("soClearFilters");
const soRefreshBtn = document.getElementById("soRefreshBtn");
const soDeleteAllBtn = document.getElementById("soDeleteAllBtn");
const soResultCount = document.getElementById("soResultCount");

const soMetricTotal = document.getElementById("soMetricTotal");
const soMetricPending = document.getElementById("soMetricPending");
const soMetricCompleted = document.getElementById("soMetricCompleted");
const soMetricCancelled = document.getElementById("soMetricCancelled");

let allReports = [];
let allMaterials = [];
let allWithdrawals = [];
let allShopOrders = [];
let usersCache = {};
let currentPeriod = 'day';
let startDate = new Date();
let endDate = new Date();
let currentWithdrawalId = null;

// =============== TOAST ===============
function showToast(message, type = 'info') {
  const existingToast = document.querySelector('.toast');
  if (existingToast) existingToast.remove();
  
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.3s';
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// =============== TABS ===============
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', function() {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
    this.classList.add('active');
    const tabId = 'tab-' + this.dataset.tab;
    document.getElementById(tabId).classList.add('active');
    
    if (this.dataset.tab === 'withdrawals') {
      loadWithdrawals();
    }
    if (this.dataset.tab === 'shoporders') {
      loadShopOrders();
    }
  });
});

// =============== LOAD MATERIALS ===============
async function loadMaterials() {
  try {
    const materialsSnap = await getDocs(collection(db, "materials"));
    allMaterials = materialsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log('✅ Materials loaded:', allMaterials.length);
  } catch (error) {
    console.error('Failed to load materials:', error);
  }
}

// =============== DYNAMIC MATERIAL CARDS ===============
function createDynamicMaterialCards(materialsMap) {
  if (!dynamicMaterialCards) return;
  dynamicMaterialCards.innerHTML = '';

  if (Object.keys(materialsMap).length === 0) {
    dynamicMaterialCards.innerHTML = '<div class="card" style="grid-column: 1 / -1;"><h4>📦 No materials data for this period</h4></div>';
    return;
  }

  Object.entries(materialsMap).forEach(([type, weight]) => {
    const material = allMaterials.find(m => m.type?.toLowerCase() === type?.toLowerCase());
    const icon = material?.icon || '📦';
    const name = material?.name || type;
    const color = material?.color || '#00C76A';

    const card = document.createElement('article');
    card.className = 'card';
    card.style.borderLeft = `4px solid ${color}`;
    card.innerHTML = `<h4>${icon} ${name}</h4><h2>${weight.toFixed(2)} kg</h2>`;
    dynamicMaterialCards.appendChild(card);
  });
}

// =============== PERIOD ===============
function setPeriod(period) {
  currentPeriod = period;
  const now = new Date();
  
  switch (period) {
    case 'day':
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      endDate = now;
      break;
    case 'week':
      const day = now.getDay();
      startDate = new Date(now);
      startDate.setDate(now.getDate() - day);
      startDate.setHours(0, 0, 0, 0);
      endDate = now;
      break;
    case 'month':
      startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      endDate = now;
      break;
    case 'year':
      startDate = new Date(now.getFullYear(), 0, 1, 0, 0, 0);
      endDate = now;
      break;
  }
  
  updateDateRangeDisplay();
  loadReports();
}

function updateDateRangeDisplay() {
  if (!dateRangeDisplay) return;
  const options = { year: 'numeric', month: 'short', day: 'numeric' };
  dateRangeDisplay.textContent = `From: ${startDate.toLocaleDateString('en-GB', options)} - To: ${endDate.toLocaleDateString('en-GB', options)}`;
}

document.querySelectorAll('.period-btn').forEach(btn => {
  btn.addEventListener('click', function() {
    document.querySelectorAll('.period-btn').forEach(b => b.classList.remove('active'));
    this.classList.add('active');
    setPeriod(this.dataset.period);
  });
});

// =============== HELPERS ===============
function normaliseText(value) {
  return String(value ?? "").trim();
}

function classifyStatus(status) {
  const value = normaliseText(status).toLowerCase();
  if (value.includes("approved") || value.includes("done") || value.includes("complete")) return "approved";
  if (value.includes("reject") || value.includes("issue")) return "rejected";
  return "pending";
}

function toReportRecord(reportData) {
  const materials = reportData.materials || {};
  
  return {
    firestoreId: reportData.id || reportData.reportId,
    reportId: normaliseText(reportData.reportId || reportData.id),
    employeeId: normaliseText(reportData.employeeDisplayId || reportData.employeeId || ''),
    employeeUid: reportData.employeeId || '',
    employeeName: normaliseText(reportData.employeeName || ''),
    warehouseId: reportData.warehouseId || '',
    warehouseName: reportData.warehouseName || '',
    materials: materials,
    totalWeight: Number(reportData.totalWeight || 0),
    points: Number(reportData.totalPoints || reportData.points || 0),
    status: normaliseText(reportData.status || "pending"),
    note: normaliseText(reportData.note || reportData.notes || ""),
    reportDate: reportData.reportDate || '',
    processCount: reportData.processCount || 0,
    createdAt: reportData.createdAt?._seconds 
      ? new Date(reportData.createdAt._seconds * 1000) 
      : (reportData.createdAt instanceof Date ? reportData.createdAt : new Date())
  };
}

function updateMetrics(records) {
  const total = records.length;
  const approved = records.filter((r) => classifyStatus(r.status) === "approved").length;
  const pending = records.filter((r) => classifyStatus(r.status) === "pending").length;
  const rejected = records.filter((r) => classifyStatus(r.status) === "rejected").length;
  
  if (metricTotal) metricTotal.textContent = total;
  if (metricCompleted) metricCompleted.textContent = approved;
  if (metricPending) metricPending.textContent = pending;
  if (metricIssues) metricIssues.textContent = rejected;
  
  const materialsMap = {};
  records.forEach(record => {
    if (record.materials && typeof record.materials === 'object') {
      Object.entries(record.materials).forEach(([type, weight]) => {
        materialsMap[type] = (materialsMap[type] || 0) + Number(weight || 0);
      });
    }
  });
  
  createDynamicMaterialCards(materialsMap);
}

function getFilteredReports() {
  const searchTerm = searchInput.value.trim().toLowerCase();
  const statusTerm = statusFilter.value;

  return allReports.filter((record) => {
    const materialsText = Object.entries(record.materials || {})
      .map(([k, v]) => `${k}:${v}`)
      .join(' ');
    
    const matchesSearch = !searchTerm || [
      record.reportId, record.employeeId, record.employeeName,
      record.status, record.note, record.warehouseName,
      record.reportDate, materialsText
    ].join(" ").toLowerCase().includes(searchTerm);

    const statusClass = classifyStatus(record.status);
    const matchesStatus = statusTerm === "all" || 
      (statusTerm === "done" && statusClass === "approved") ||
      (statusTerm === "pending" && statusClass === "pending") ||
      (statusTerm === "issue" && statusClass === "rejected");

    return matchesSearch && matchesStatus;
  });
}

// =============== RENDER REPORTS ===============
function renderReports() {
  const filteredReports = getFilteredReports();
  tableBody.innerHTML = "";

  if (filteredReports.length === 0) {
    tableBody.innerHTML = `<tr><td colspan="7" class="empty-state">No reports match the current filters.</td></tr>`;
    resultCount.textContent = allReports.length ? "No results for the selected filters." : "Waiting for report data...";
    return;
  }

  filteredReports.forEach((record, index) => {
    const statusClass = classifyStatus(record.status);
    const badgeClass = statusClass === "approved" ? "badge done" : 
                       statusClass === "pending" ? "badge pending" : "badge issue";
    const badgeText = statusClass === "approved" ? "Approved" : 
                      statusClass === "pending" ? "Pending" : "Rejected";
    
    let amountHtml = '';
    if (record.materials && Object.keys(record.materials).length > 0) {
      amountHtml = '<div class="amount-cell">';
      Object.entries(record.materials).forEach(([type, weight]) => {
        const material = allMaterials.find(m => m.type?.toLowerCase() === type?.toLowerCase());
        const icon = material?.icon || '📦';
        const name = material?.name || type;
        amountHtml += `
          <div class="amount-item">
            <span class="amount-icon">${icon}</span>
            ${name}: ${Number(weight).toFixed(2)} kg
          </div>
        `;
      });
      amountHtml += '</div>';
    } else {
      amountHtml = `${record.totalWeight.toFixed(2)} kg`;
    }

    const createdDate = record.createdAt instanceof Date 
      ? record.createdAt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })
      : 'N/A';

    const rowId = `row-${index}`;
    const approveBtnId = `approve-${index}`;
    const deleteBtnId = `delete-${index}`;

    const approveBtn = (statusClass === 'pending') 
      ? `<button type="button" id="${approveBtnId}" class="row-action approve-btn">✅ Approve</button>`
      : '';
    
    const deleteBtn = `<button type="button" id="${deleteBtnId}" class="row-action delete-btn">🗑️ Delete</button>`;

    tableBody.insertAdjacentHTML("beforeend", `
      <tr id="${rowId}" class="${statusClass === 'approved' ? 'row-approved' : ''}">
        <td>
          <div style="font-weight:600;">${record.reportId}</div>
          <div style="font-size:11px;color:#8A8A98;">${createdDate}</div>
        </td>
        <td>
          <div>${record.employeeId || "-"}</div>
          <div style="font-size:12px;color:#8A8A98;">${record.warehouseName || ''}</div>
        </td>
        <td>${amountHtml}</td>
        <td style="font-weight:700;color:#00C76A;">${record.points} pts</td>
        <td><span class="${badgeClass}">${badgeText}</span></td>
        <td>${record.note || "-"}</td>
        <td style="display:flex;gap:6px;flex-wrap:wrap;">
          ${approveBtn}
          ${deleteBtn}
        </td>
      </tr>
    `);

    setTimeout(() => {
      if (statusClass === 'pending') {
        const approveBtnEl = document.getElementById(approveBtnId);
        if (approveBtnEl) {
          approveBtnEl.onclick = function(e) {
            e.preventDefault();
            e.stopPropagation();
            const uidToUse = record.employeeUid || record.employeeId;
            handleApprove(record.firestoreId, uidToUse);
          };
        }
      }
      
      const deleteBtnEl = document.getElementById(deleteBtnId);
      if (deleteBtnEl) {
        deleteBtnEl.onclick = function(e) {
          e.preventDefault();
          e.stopPropagation();
          handleDelete(record.firestoreId);
        };
      }
    }, 0);
  });

  resultCount.textContent = `Showing ${filteredReports.length} of ${allReports.length} reports`;
}

// =============== LOAD REPORTS ===============
async function loadReports() {
  try {
    resultCount.textContent = "Loading reports...";
    tableBody.innerHTML = `<tr><td colspan="7" class="empty-state"><div class="spinner"></div>Loading reports...</td></tr>`;
    
    await loadMaterials();
    
    const reportsSnap = await getDocs(query(
      collection(db, "reports"),
      orderBy("createdAt", "desc")
    ));
    
    let reports = reportsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log('📊 Total reports:', reports.length);
    
    if (!isSuperAdmin && adminWarehouseId !== 'all') {
      reports = reports.filter(r => r.warehouseId === adminWarehouseId);
      console.log('📊 After warehouse filter:', reports.length);
    }
    
    reports = reports.filter(r => {
      if (r.createdAt?._seconds) {
        const date = new Date(r.createdAt._seconds * 1000);
        return date >= startDate && date <= endDate;
      }
      if (r.createdAt instanceof Date) {
        return r.createdAt >= startDate && r.createdAt <= endDate;
      }
      return true;
    });
    
    allReports = reports.map(toReportRecord);
    updateMetrics(allReports);
    renderReports();
  } catch (error) {
    console.error("❌ Failed to load reports:", error);
    resultCount.textContent = "Unable to load reports.";
    tableBody.innerHTML = `<tr><td colspan="7" class="empty-state">❌ Failed to load reports.</td></tr>`;
  }
}

// =============== DELETE ===============
async function handleDelete(reportId) {
  if (!confirm("⚠️ Delete this report? This cannot be undone.")) return;
  
  try {
    showToast('Deleting report...', 'info');
    await deleteDoc(doc(db, "reports", reportId));
    showToast('✅ Report deleted!', 'success');
    await loadReports();
  } catch (error) {
    console.error("❌ Failed to delete:", error);
    showToast('❌ Failed: ' + error.message, 'error');
  }
}

// =============== APPROVE ===============
async function handleApprove(reportId, employeeId) {
  if (!confirm("✅ Approve this report?\n\nThis will mark the report as Approved.\nNo data will be deleted from Firebase.\nThe mobile app inventory will reset automatically.")) return;
  
  try {
    showToast('Approving report...', 'info');
    
    let actualUid = employeeId;
    
    if (employeeId && employeeId.includes('-') && employeeId.length < 10) {
      const employeesSnap = await getDocs(query(
        collection(db, "employees"),
        where("displayId", "==", employeeId)
      ));
      
      if (!employeesSnap.empty) {
        actualUid = employeesSnap.docs[0].id;
      }
    }
    
    await updateDoc(doc(db, "reports", reportId), {
      status: "approved",
      approvedAt: serverTimestamp(),
      approvedBy: adminEmail
    });
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTimestamp = Timestamp.fromDate(today);
    
    let processesSnap = await getDocs(query(
      collection(db, "recycling_processes"),
      where("employeeId", "==", actualUid),
      where("scannedAt", ">=", todayTimestamp)
    ));
    
    if (processesSnap.empty) {
      processesSnap = await getDocs(query(
        collection(db, "recycling_processes"),
        where("employeeId", "==", employeeId),
        where("scannedAt", ">=", todayTimestamp)
      ));
    }
    
    if (!processesSnap.empty) {
      const batch = writeBatch(db);
      processesSnap.docs.forEach(procDoc => {
        batch.update(procDoc.ref, {
          reported: true,
          reportId: reportId,
          reportedAt: serverTimestamp()
        });
      });
      await batch.commit();
    }
    
    let inventorySnap = await getDocs(query(
      collection(db, "inventory"),
      where("employeeId", "==", actualUid)
    ));
    
    if (inventorySnap.empty) {
      inventorySnap = await getDocs(query(
        collection(db, "inventory"),
        where("employeeId", "==", employeeId)
      ));
    }
    
    if (!inventorySnap.empty) {
      const batch2 = writeBatch(db);
      inventorySnap.docs.forEach(invDoc => {
        batch2.update(invDoc.ref, {
          weight: 0,
          lastUpdated: serverTimestamp(),
          lastReset: serverTimestamp()
        });
      });
      await batch2.commit();
    }
    
    showToast('✅ Report approved! Mobile app inventory will reset.', 'success');
    await loadReports();
  } catch (error) {
    console.error("❌ Failed to approve:", error);
    showToast('❌ Failed: ' + error.message, 'error');
  }
}

// =============================================
// =============== WITHDRAWALS =================
// =============================================

async function loadWithdrawals() {
  try {
    wResultCount.textContent = "Loading withdrawal requests...";
    wTableBody.innerHTML = `<tr><td colspan="10" class="empty-state"><div class="spinner"></div>Loading withdrawal requests...</td></tr>`;
    
    const usersSnap = await getDocs(collection(db, "users"));
    usersCache = {};
    usersSnap.docs.forEach(doc => {
      const data = doc.data();
      usersCache[doc.id] = {
        displayId: data.displayId || doc.id,
        phone: data.phone || '-',
        name: `${data.firstName || ''} ${data.lastName || ''}`.trim() || '-'
      };
    });
    console.log('👥 Users cached:', Object.keys(usersCache).length);
    
    const withdrawalsSnap = await getDocs(query(
      collection(db, "withdrawal_requests"),
      orderBy("createdAt", "desc")
    ));
    
    let withdrawals = withdrawalsSnap.docs.map(doc => {
      const data = doc.data();
      return { id: doc.id, ...data };
    });
    
    console.log('💳 Total withdrawals loaded:', withdrawals.length);
    
    allWithdrawals = withdrawals;
    updateWithdrawalMetrics(withdrawals);
    renderWithdrawals();
  } catch (error) {
    console.error("❌ Failed to load withdrawals:", error);
    wResultCount.textContent = "Unable to load withdrawal requests.";
    wTableBody.innerHTML = `<tr><td colspan="10" class="empty-state">❌ Failed to load withdrawal requests.</td></tr>`;
  }
}

function updateWithdrawalMetrics(requests) {
  const today = new Date();
  const todayStart = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0, 0);
  
  const todayRequests = requests.filter(r => {
    if (!r.createdAt) return false;
    const status = (r.status || '').toLowerCase().trim();
    if (status === 'rejected') return false;
    
    let requestDate;
    if (r.createdAt._seconds) {
      requestDate = new Date(r.createdAt._seconds * 1000);
    } else if (r.createdAt instanceof Date) {
      requestDate = r.createdAt;
    } else if (typeof r.createdAt.toDate === 'function') {
      requestDate = r.createdAt.toDate();
    } else {
      return false;
    }
    
    return requestDate >= todayStart;
  });
  
  const pendingRequests = requests.filter(r => (r.status || '').toLowerCase().trim() === 'pending');
  const completedRequests = requests.filter(r => (r.status || '').toLowerCase().trim() === 'completed');
  
  let totalAmountToday = 0;
  todayRequests.forEach(r => { totalAmountToday += Number(r.amountEgp || 0); });
  
  if (wMetricToday) wMetricToday.textContent = todayRequests.length;
  if (wMetricAmount) wMetricAmount.textContent = Math.round(totalAmountToday) + ' EGP';
  if (wMetricPending) wMetricPending.textContent = pendingRequests.length;
  if (wMetricCompleted) wMetricCompleted.textContent = completedRequests.length;
}

function getFilteredWithdrawals() {
  const searchTerm = wSearchInput.value.trim().toLowerCase();
  const statusTerm = wStatusFilter.value;

  return allWithdrawals.filter((request) => {
    const userInfo = usersCache[request.userId] || {};
    const displayId = userInfo.displayId || request.userId || '';
    const phone = userInfo.phone || '';
    
    const matchesSearch = !searchTerm || [
      request.transactionId, request.companyName, request.cardNumber,
      request.serviceType, request.referenceNumber, displayId, phone
    ].join(" ").toLowerCase().includes(searchTerm);

    const requestStatus = (request.status || 'pending').toLowerCase().trim();
    const matchesStatus = statusTerm === "all" || requestStatus === statusTerm;

    return matchesSearch && matchesStatus;
  });
}

function renderWithdrawals() {
  const filtered = getFilteredWithdrawals();
  wTableBody.innerHTML = "";

  if (filtered.length === 0) {
    wTableBody.innerHTML = `<tr><td colspan="10" class="empty-state">No withdrawal requests match the current filters.</td></tr>`;
    wResultCount.textContent = allWithdrawals.length ? "No results for the selected filters." : "Waiting for withdrawal data...";
    return;
  }

  filtered.forEach((request, index) => {
    const status = (request.status || 'pending').toLowerCase().trim();
    let badgeClass, badgeText;
    
    switch (status) {
      case 'completed':
        badgeClass = 'badge completed';
        badgeText = 'Completed';
        break;
      case 'rejected':
        badgeClass = 'badge rejected';
        badgeText = 'Rejected';
        break;
      default:
        badgeClass = 'badge pending';
        badgeText = 'Pending';
    }

    const userInfo = usersCache[request.userId] || { displayId: request.userId || '-', phone: '-', name: '-' };
    
    let createdDate = 'N/A';
    if (request.createdAt?._seconds) {
      createdDate = new Date(request.createdAt._seconds * 1000).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    } else if (request.createdAt instanceof Date) {
      createdDate = request.createdAt.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    } else if (typeof request.createdAt?.toDate === 'function') {
      createdDate = request.createdAt.toDate().toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    }

    let serviceTypeText = '';
    switch ((request.serviceType || '').toLowerCase()) {
      case 'water': serviceTypeText = '💧 Water'; break;
      case 'electricity': serviceTypeText = '⚡ Electricity'; break;
      case 'gas': serviceTypeText = '🔥 Gas'; break;
      default: serviceTypeText = request.serviceType || '-';
    }

    const confirmBtn = (status === 'pending')
      ? `<button type="button" class="row-action confirm-btn" data-action="confirm" data-id="${request.id}">✅ Confirm</button>`
      : '';
    
    const rejectBtn = (status === 'pending')
      ? `<button type="button" class="row-action reject-btn" data-action="reject" data-id="${request.id}">❌ Reject</button>`
      : '';

    wTableBody.insertAdjacentHTML("beforeend", `
      <tr>
        <td style="font-weight:600;">${request.transactionId || request.id}</td>
        <td style="font-weight:600;color:#00C76A;">${userInfo.displayId}</td>
        <td>${userInfo.phone}</td>
        <td>${serviceTypeText}</td>
        <td>${request.companyName || '-'}</td>
        <td style="font-weight:700;">${Number(request.amountEgp || 0).toFixed(2)} EGP</td>
        <td style="font-weight:600;color:#00C76A;">${request.pointsUsed || 0}</td>
        <td><span class="${badgeClass}">${badgeText}</span></td>
        <td style="font-size:12px;">${createdDate}</td>
        <td style="display:flex;gap:6px;flex-wrap:wrap;">
          ${confirmBtn}
          ${rejectBtn}
        </td>
      </tr>
    `);
  });

  document.querySelectorAll('[data-action="confirm"]').forEach(btn => {
    btn.onclick = function(e) {
      e.preventDefault();
      const requestId = this.dataset.id;
      const request = allWithdrawals.find(r => r.id === requestId);
      if (request) openConfirmModal(request);
    };
  });

  document.querySelectorAll('[data-action="reject"]').forEach(btn => {
    btn.onclick = function(e) {
      e.preventDefault();
      const requestId = this.dataset.id;
      const request = allWithdrawals.find(r => r.id === requestId);
      if (request) openRejectModal(request);
    };
  });

  wResultCount.textContent = `Showing ${filtered.length} of ${allWithdrawals.length} requests`;
}

// =========== CONFIRM/REJECT MODALS (كما هي لم تتغير) ===========
function openConfirmModal(request) {
  currentWithdrawalId = request.id;
  const userInfo = usersCache[request.userId] || { displayId: request.userId, phone: '-' };
  confirmModalInfo.innerHTML = `
    <p><strong>Transaction ID:</strong> ${request.transactionId || request.id}</p>
    <p><strong>User:</strong> ${userInfo.displayId}</p>
    <p><strong>Phone:</strong> ${userInfo.phone}</p>
    <p><strong>Company:</strong> ${request.companyName || '-'}</p>
    <p><strong>Amount:</strong> ${Number(request.amountEgp || 0).toFixed(2)} EGP</p>
    <p><strong>Points:</strong> ${request.pointsUsed || 0}</p>
  `;
  referenceInput.value = '';
  confirmModal.style.display = 'flex';
}

function closeConfirmModal() {
  confirmModal.style.display = 'none';
  currentWithdrawalId = null;
}

if (cancelConfirmBtn) {
  cancelConfirmBtn.addEventListener('click', function(e) {
    e.preventDefault();
    closeConfirmModal();
  });
}

if (confirmTransferBtn) {
  confirmTransferBtn.addEventListener('click', async function() {
    const referenceNumber = referenceInput.value.trim();
    if (!referenceNumber) {
      showToast('Please enter the reference number', 'error');
      return;
    }
    if (!currentWithdrawalId) return;
    
    try {
      this.disabled = true;
      this.textContent = 'Processing...';
      showToast('Confirming transfer...', 'info');
      
      const requestSnap = await getDocs(query(
        collection(db, "withdrawal_requests"),
        where("__name__", "==", currentWithdrawalId)
      ));
      
      let userId = null;
      let amountEgp = 0;
      let serviceType = '';
      
      if (!requestSnap.empty) {
        const requestData = requestSnap.docs[0].data();
        userId = requestData.userId;
        amountEgp = Number(requestData.amountEgp || 0);
        serviceType = requestData.serviceType || '';
      }
      
      await updateDoc(doc(db, "withdrawal_requests", currentWithdrawalId), {
        status: "completed",
        referenceNumber: referenceNumber,
        processedBy: adminEmail,
        processedAt: serverTimestamp()
      });
      
      if (userId) {
        const serviceName = serviceType === 'water' ? 'مياه' : 
                           serviceType === 'electricity' ? 'كهرباء' : 
                           serviceType === 'gas' ? 'غاز' : serviceType;
        
        await addDoc(collection(db, "notifications"), {
          userId: userId,
          title: '✅ تم تأكيد الشحن',
          body: `تم تأكيد شحن ${serviceName} بقيمة ${amountEgp.toFixed(2)} جنيه. الرقم المرجعي: ${referenceNumber}`,
          type: 'withdrawal',
          transactionId: currentWithdrawalId,
          isRead: false,
          createdAt: serverTimestamp()
        });
      }
      
      showToast('✅ Transfer confirmed successfully!', 'success');
      closeConfirmModal();
      await loadWithdrawals();
    } catch (error) {
      console.error("❌ Failed to confirm:", error);
      showToast('❌ Failed: ' + error.message, 'error');
    } finally {
      this.disabled = false;
      this.textContent = 'Confirm Transfer';
    }
  });
}

function openRejectModal(request) {
  currentWithdrawalId = request.id;
  const userInfo = usersCache[request.userId] || { displayId: request.userId, phone: '-' };
  rejectModalInfo.innerHTML = `
    <p><strong>Transaction ID:</strong> ${request.transactionId || request.id}</p>
    <p><strong>User:</strong> ${userInfo.displayId}</p>
    <p><strong>Phone:</strong> ${userInfo.phone}</p>
    <p><strong>Company:</strong> ${request.companyName || '-'}</p>
    <p><strong>Amount:</strong> ${Number(request.amountEgp || 0).toFixed(2)} EGP</p>
  `;
  rejectNotesInput.value = '';
  rejectModal.style.display = 'flex';
}

function closeRejectModal() {
  rejectModal.style.display = 'none';
  currentWithdrawalId = null;
}

if (cancelRejectBtn) {
  cancelRejectBtn.addEventListener('click', function(e) {
    e.preventDefault();
    closeRejectModal();
  });
}

if (rejectTransferBtn) {
  rejectTransferBtn.addEventListener('click', async function() {
    const notes = rejectNotesInput.value.trim();
    if (!notes) {
      showToast('Please enter the rejection reason', 'error');
      return;
    }
    if (!currentWithdrawalId) return;
    
    try {
      this.disabled = true;
      this.textContent = 'Processing...';
      showToast('Rejecting request and refunding points...', 'info');
      
      const requestSnap = await getDocs(query(
        collection(db, "withdrawal_requests"),
        where("__name__", "==", currentWithdrawalId)
      ));
      
      if (!requestSnap.empty) {
        const requestData = requestSnap.docs[0].data();
        const userId = requestData.userId;
        const pointsUsed = Number(requestData.pointsUsed || 0);
        const amountEgp = Number(requestData.amountEgp || 0);
        const serviceType = requestData.serviceType || '';
        
        await updateDoc(doc(db, "withdrawal_requests", currentWithdrawalId), {
          status: "rejected",
          notes: notes,
          processedBy: adminEmail,
          processedAt: serverTimestamp()
        });
        
        if (userId && pointsUsed > 0) {
          const userSnap = await getDocs(query(
            collection(db, "users"),
            where("__name__", "==", userId)
          ));
          
          if (!userSnap.empty) {
            const userData = userSnap.docs[0].data();
            const currentPoints = Number(userData.points || 0);
            await updateDoc(doc(db, "users", userId), {
              points: currentPoints + pointsUsed
            });
          }
        }
        
        if (userId) {
          const serviceName = serviceType === 'water' ? 'مياه' : 
                             serviceType === 'electricity' ? 'كهرباء' : 
                             serviceType === 'gas' ? 'غاز' : serviceType;
          
          await addDoc(collection(db, "notifications"), {
            userId: userId,
            title: '❌ تم رفض طلب الشحن',
            body: `تم رفض طلب شحن ${serviceName} بقيمة ${amountEgp.toFixed(2)} جنيه. السبب: ${notes}. تم إرجاع ${pointsUsed} نقطة.`,
            type: 'withdrawal',
            transactionId: currentWithdrawalId,
            isRead: false,
            createdAt: serverTimestamp()
          });
        }
      }
      
      showToast('✅ Request rejected and points refunded!', 'success');
      closeRejectModal();
      await loadWithdrawals();
    } catch (error) {
      console.error("❌ Failed to reject:", error);
      showToast('❌ Failed: ' + error.message, 'error');
    } finally {
      this.disabled = false;
      this.textContent = 'Reject Request';
    }
  });
}

// =============== DELETE ALL WITHDRAWALS ===============
if (wDeleteAllBtn) {
  wDeleteAllBtn.addEventListener("click", async function() {
    if (!confirm("⚠️ Delete ALL withdrawal requests?\n\nThis will permanently delete all withdrawal requests from the database.\nThis action CANNOT be undone!")) return;
    if (!confirm("⚠️ Are you REALLY sure?\n\nThis is your final warning!")) return;
    
    try {
      this.disabled = true;
      this.textContent = 'Deleting...';
      showToast('Deleting all withdrawal requests...', 'info');
      
      const allSnap = await getDocs(collection(db, "withdrawal_requests"));
      const batch = writeBatch(db);
      let deleteCount = 0;
      
      allSnap.docs.forEach(doc => {
        batch.delete(doc.ref);
        deleteCount++;
      });
      
      if (deleteCount > 0) {
        await batch.commit();
        showToast(`✅ Deleted ${deleteCount} withdrawal requests! Dashboard cleared.`, 'success');
      } else {
        showToast('No withdrawal requests to delete.', 'info');
      }
      
      allWithdrawals = [];
      updateWithdrawalMetrics([]);
      renderWithdrawals();
      
    } catch (error) {
      console.error("❌ Failed to delete all:", error);
      showToast('❌ Failed: ' + error.message, 'error');
    } finally {
      this.disabled = false;
      this.textContent = '🗑️ Delete All';
    }
  });
}

// =============== WITHDRAWAL EVENT LISTENERS ===============
wSearchInput.addEventListener("input", renderWithdrawals);
wStatusFilter.addEventListener("change", renderWithdrawals);
wClearFiltersBtn.addEventListener("click", () => {
  wSearchInput.value = "";
  wStatusFilter.value = "all";
  renderWithdrawals();
});
wRefreshBtn.addEventListener("click", () => {
  usersCache = {};
  loadWithdrawals();
});

// =============================================
// =============== SHOP ORDERS =================
// =============================================

async function loadShopOrders() {
  try {
    soResultCount.textContent = "Loading orders...";
    soTableBody.innerHTML = `<tr><td colspan="8" class="empty-state"><div class="spinner"></div>Loading orders...</td></tr>`;
    
    const snap = await getDocs(query(
      collection(db, "shop_orders"),
      orderBy("createdAt", "desc")
    ));
    
    allShopOrders = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log('📦 Shop orders loaded:', allShopOrders.length);
    
    updateShopOrderMetrics();
    renderShopOrders();
  } catch (error) {
    console.error("❌ Shop orders error:", error);
    soTableBody.innerHTML = `<tr><td colspan="8" class="empty-state">❌ Failed to load orders.</td></tr>`;
  }
}

function updateShopOrderMetrics() {
  if (soMetricTotal) soMetricTotal.textContent = allShopOrders.length;
  if (soMetricPending) soMetricPending.textContent = allShopOrders.filter(o => o.status === 'pending').length;
  if (soMetricCompleted) soMetricCompleted.textContent = allShopOrders.filter(o => o.status === 'completed').length;
  if (soMetricCancelled) soMetricCancelled.textContent = allShopOrders.filter(o => o.status === 'cancelled').length;
}

function getFilteredShopOrders() {
  const searchTerm = soSearchInput.value.trim().toLowerCase();
  const statusTerm = soStatusFilter.value;

  return allShopOrders.filter(order => {
    const matchesSearch = !searchTerm || [
      order.material, order.phone, order.id
    ].join(" ").toLowerCase().includes(searchTerm);

    const matchesStatus = statusTerm === "all" || order.status === statusTerm;

    return matchesSearch && matchesStatus;
  });
}

function renderShopOrders() {
  const filtered = getFilteredShopOrders();
  soTableBody.innerHTML = "";

  if (filtered.length === 0) {
    soTableBody.innerHTML = `<tr><td colspan="8" class="empty-state">No orders found.</td></tr>`;
    soResultCount.textContent = allShopOrders.length ? "No results for the selected filters." : "Waiting for order data...";
    return;
  }

  filtered.forEach(order => {
    let badgeClass, badgeText;
    
    switch (order.status) {
      case 'completed':
        badgeClass = 'badge completed';
        badgeText = 'Completed';
        break;
      case 'cancelled':
        badgeClass = 'badge rejected';
        badgeText = 'Cancelled';
        break;
      default:
        badgeClass = 'badge pending';
        badgeText = 'Pending';
    }

    let date = 'N/A';
    if (order.createdAt?.toDate) {
      date = order.createdAt.toDate().toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
    } else if (order.createdAt?._seconds) {
      date = new Date(order.createdAt._seconds * 1000).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
    }

    const actions = order.status === 'pending'
      ? `<button class="row-action confirm-btn" data-so-complete="${order.id}">✅ Complete</button>
         <button class="row-action reject-btn" data-so-cancel="${order.id}">❌ Cancel</button>`
      : '';

    soTableBody.insertAdjacentHTML("beforeend", `
      <tr>
        <td style="font-size:12px;font-weight:600;">${order.id.slice(-8)}</td>
        <td>${order.material || '-'}</td>
        <td>${order.quantityKg || 0} kg</td>
        <td style="font-weight:700;">${order.totalPrice || 0} EGP</td>
        <td>${order.phone || '-'}</td>
        <td><span class="${badgeClass}">${badgeText}</span></td>
        <td style="font-size:12px;">${date}</td>
        <td style="display:flex;gap:6px;flex-wrap:wrap;">${actions}</td>
      </tr>
    `);
  });

  document.querySelectorAll('[data-so-complete]').forEach(btn => {
    btn.onclick = function(e) {
      e.preventDefault();
      completeOrder(this.dataset.soComplete);
    };
  });

  document.querySelectorAll('[data-so-cancel]').forEach(btn => {
    btn.onclick = function(e) {
      e.preventDefault();
      cancelOrder(this.dataset.soCancel);
    };
  });

  soResultCount.textContent = `Showing ${filtered.length} of ${allShopOrders.length} orders`;
}

async function completeOrder(orderId) {
  try {
    await updateDoc(doc(db, "shop_orders", orderId), { status: "completed" });
    showToast('✅ Order completed!', 'success');
    loadShopOrders();
  } catch (error) {
    showToast('❌ Failed: ' + error.message, 'error');
  }
}

async function cancelOrder(orderId) {
  try {
    await updateDoc(doc(db, "shop_orders", orderId), { status: "cancelled" });
    showToast('❌ Order cancelled.', 'info');
    loadShopOrders();
  } catch (error) {
    showToast('❌ Failed: ' + error.message, 'error');
  }
}

// =============== SHOP ORDERS EVENTS ===============
soSearchInput.addEventListener("input", renderShopOrders);
soStatusFilter.addEventListener("change", renderShopOrders);
soClearFiltersBtn.addEventListener("click", () => {
  soSearchInput.value = "";
  soStatusFilter.value = "all";
  renderShopOrders();
});
soRefreshBtn.addEventListener("click", loadShopOrders);

if (soDeleteAllBtn) {
  soDeleteAllBtn.addEventListener("click", async function() {
    if (!confirm("⚠️ Delete ALL shop orders?\n\nThis action CANNOT be undone!")) return;
    
    try {
      this.disabled = true;
      this.textContent = 'Deleting...';
      showToast('Deleting all orders...', 'info');
      
      const snap = await getDocs(collection(db, "shop_orders"));
      const batch = writeBatch(db);
      snap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
      
      showToast(`✅ Deleted ${snap.docs.length} orders!`, 'success');
      allShopOrders = [];
      updateShopOrderMetrics();
      renderShopOrders();
    } catch (error) {
      showToast('❌ Failed: ' + error.message, 'error');
    } finally {
      this.disabled = false;
      this.textContent = '🗑️ Delete All';
    }
  });
}

// =============== REPORTS EVENT LISTENERS ===============
searchInput.addEventListener("input", renderReports);
statusFilter.addEventListener("change", renderReports);
clearFiltersButton.addEventListener("click", () => {
  searchInput.value = "";
  statusFilter.value = "all";
  renderReports();
});
refreshBtn.addEventListener("click", () => {
  loadReports();
});

// =============== INIT ===============
function updateUIBasedOnRole() {
  const adminLabel = document.querySelector('.admin-label');
  if (adminLabel) {
    if (isSuperAdmin) {
      adminLabel.textContent = '🔑 Super Admin - All Warehouses';
      adminLabel.style.color = '#00C76A';
    } else {
      adminLabel.textContent = `👤 Admin - ${adminData.warehouseName || 'Warehouse'}`;
      adminLabel.style.color = '#8A8A98';
    }
  }

  if (!isSuperAdmin) {
    const tabsContainer = document.getElementById('tabsContainer');
    if (tabsContainer) {
      tabsContainer.style.display = 'none';
    }
    const tabWithdrawals = document.getElementById('tab-withdrawals');
    if (tabWithdrawals) tabWithdrawals.classList.remove('active');
    const tabShopOrders = document.getElementById('tab-shoporders');
    if (tabShopOrders) tabShopOrders.classList.remove('active');
    const tabReports = document.getElementById('tab-reports');
    if (tabReports) tabReports.classList.add('active');
  }
  
  const formPanel = document.querySelector('.form-panel');
  if (formPanel) formPanel.style.display = 'none';
  
  const exportBtn = document.getElementById('exportBtn');
  if (exportBtn) exportBtn.style.display = 'none';
}

updateUIBasedOnRole();
setPeriod('day');
loadReports();
setInterval(loadReports, 30000);

console.log('🚀 Report Dashboard Ready');