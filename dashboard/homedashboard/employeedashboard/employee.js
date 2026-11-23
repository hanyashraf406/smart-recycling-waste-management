import { db } from "../../firebase-config.js";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  deleteDoc,
  serverTimestamp,
  updateDoc,
  writeBatch
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';
const adminEmail = adminData.email || 'admin';

console.log('👤 Role:', adminData.role, '| 🏭 Warehouse:', adminWarehouseId);

const employeeSearch = document.getElementById("employeeSearch");
const employeeTableBody = document.querySelector("#employeeTable tbody");
const selectAll = document.getElementById("selectAll");
const deleteBtn = document.getElementById("deleteSelectedBtn");
const totalEmployees = document.getElementById("totalEmployees");
const shiftEmployees = document.getElementById("shiftEmployees");
const absentEmployees = document.getElementById("absentEmployees");
const breakEmployees = document.getElementById("breakEmployees");

const codeDisplay = document.getElementById("codeDisplay");
const codeLastUpdate = document.getElementById("codeLastUpdate");
const toggleCodeBtn = document.getElementById("toggleCodeBtn");
const changeCodeBtn = document.getElementById("changeCodeBtn");
const warehouseSelect = document.getElementById("warehouseSelect");
const codeModal = document.getElementById("codeModal");
const codeModalWarehouse = document.getElementById("codeModalWarehouse");
const currentCodeInput = document.getElementById("currentCodeInput");
const newSecretCode = document.getElementById("newSecretCode");
const confirmSecretCode = document.getElementById("confirmSecretCode");
const saveCodeBtn = document.getElementById("saveCodeBtn");

let employees = [];
let selectedIds = new Set();
let searchTerm = "";
let codeVisible = false;
let currentWarehouseData = null;
let allWarehouses = [];

function showToast(message, type = 'info') {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
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

function normalizeStatus(status, isBlocked, isApproved) {
  if (isApproved === false) return "Pending";
  if (isBlocked === true) return "Absent";
  const v = String(status || "").trim().toLowerCase();
  if (v === "break") return "Break";
  if (v === "absent" || v === "blocked") return "Absent";
  return "Shift";
}

function getStatusClass(status) {
  const s = status.toLowerCase();
  if (s === "pending") return "status-pending";
  if (s === "absent") return "status-absent";
  if (s === "break") return "status-break";
  return "status-shift";
}

function formatDate(value) {
  if (value?.toDate) return value.toDate().toLocaleDateString("en-GB");
  if (value?._seconds) return new Date(value._seconds * 1000).toLocaleDateString("en-GB");
  if (typeof value === "string" && value.trim()) return value;
  return new Date().toLocaleDateString("en-GB");
}

function formatDateTime(value) {
  if (value?.toDate) return value.toDate().toLocaleString("en-GB");
  if (value?._seconds) return new Date(value._seconds * 1000).toLocaleString("en-GB");
  return 'Not updated yet';
}

function updateSummaryCards() {
  totalEmployees.textContent = employees.length;
  shiftEmployees.textContent = employees.filter(e => normalizeStatus(e.status, e.isBlocked, e.isApproved) === "Shift").length;
  absentEmployees.textContent = employees.filter(e => normalizeStatus(e.status, e.isBlocked, e.isApproved) === "Absent").length;
  breakEmployees.textContent = employees.filter(e => normalizeStatus(e.status, e.isBlocked, e.isApproved) === "Break").length;
}

function renderEmployees() {
  updateSummaryCards();

  let filtered = employees.filter(e => {
    if (!searchTerm) return true;
    const haystack = [e.employeeId, e.name, e.email, e.phone, e.warehouse, e.status]
      .filter(Boolean).join(" ").toLowerCase();
    return haystack.includes(searchTerm);
  });

  if (selectAll) {
    selectAll.checked = filtered.length > 0 && filtered.every(e => selectedIds.has(e.id));
    selectAll.indeterminate = filtered.some(e => selectedIds.has(e.id)) && !selectAll.checked;
  }

  if (!filtered.length) {
    employeeTableBody.innerHTML = '<tr><td colspan="9" class="empty-state">No employees found.</td></tr>';
    return;
  }

  employeeTableBody.innerHTML = filtered.map(emp => {
    const statusText = normalizeStatus(emp.status, emp.isBlocked, emp.isApproved);
    const isPending = statusText === 'Pending';
    const checked = selectedIds.has(emp.id) ? 'checked' : '';
    const selectedClass = selectedIds.has(emp.id) ? 'selected-row' : '';

    return `
      <tr class="${selectedClass}">
        <td><input type="checkbox" class="row-checkbox" data-employee-id="${emp.id}" ${checked}></td>
        <td>${emp.employeeId || emp.id}</td>
        <td>${emp.name}</td>
        <td>${emp.email}</td>
        <td>${emp.phone || '-'}</td>
        <td>${emp.warehouse || '-'}</td>
        <td>${formatDate(emp.createdAt)}</td>
        <td>
          ${isPending 
            ? `<span class="status-badge ${getStatusClass(statusText)}">Pending</span>`
            : `<select class="status-select" data-change-status="${emp.id}">
                <option value="Shift" ${statusText === 'Shift' ? 'selected' : ''}>🟢 Shift</option>
                <option value="Break" ${statusText === 'Break' ? 'selected' : ''}>🟡 Break</option>
                <option value="Absent" ${statusText === 'Absent' ? 'selected' : ''}>🔴 Absent</option>
              </select>`
          }
        </td>
        <td>
          ${isPending ? `
            <button class="row-action-btn approve" data-approve="${emp.id}">✅ Approve</button>
            <button class="row-action-btn reject" data-reject="${emp.id}">❌ Reject</button>
          ` : ''}
        </td>
      </tr>
    `;
  }).join("");
}

function applySearch() {
  searchTerm = employeeSearch.value.trim().toLowerCase();
  renderEmployees();
}

async function loadEmployeesFromAPI() {
  try {
    const snapshot = await getDocs(collection(db, "employees"));
    let list = [];
    snapshot.forEach(doc => {
      list.push({ id: doc.id, ...doc.data() });
    });

    if (!isSuperAdmin && adminWarehouseId !== 'all') {
      list = list.filter(e =>
        e.warehouseId === adminWarehouseId ||
        e.warehouse === adminData.warehouseName
      );
    }

    employees = list.map(emp => ({
      id: emp.id || emp.userId,
      employeeId: emp.displayId || emp.employeeId || emp.id,
      name: `${emp.firstName || ''} ${emp.lastName || ''}`.trim() || emp.email?.split('@')[0] || 'N/A',
      email: emp.email || '',
      phone: emp.phone || '',
      warehouse: emp.warehouseName || emp.warehouse || '',
      warehouseId: emp.warehouseId || '',
      status: emp.status || 'shift',
      isBlocked: emp.isBlocked || false,
      isApproved: emp.isApproved !== false,
      createdAt: emp.createdAt
    }));

    const currentIds = new Set(employees.map(e => e.id));
    selectedIds = new Set([...selectedIds].filter(id => currentIds.has(id)));

    renderEmployees();
  } catch (err) {
    console.error("Load employees error:", err);
  }
}

async function changeStatus(empId, newStatus) {
  try {
    const updateData = {
      status: newStatus.toLowerCase(),
      updatedAt: serverTimestamp(),
      updatedBy: adminEmail
    };

    if (newStatus === 'Absent') updateData.isBlocked = true;
    if (newStatus === 'Shift' || newStatus === 'Break') updateData.isBlocked = false;

    await updateDoc(doc(db, "employees", empId), updateData);
    console.log(`✅ Status changed to ${newStatus} for ${empId}`);
    loadEmployeesFromAPI();
  } catch (err) {
    console.error("Change status error:", err);
    alert("Failed to change status.");
  }
}

async function approveEmployee(empId) {
  try {
    await updateDoc(doc(db, "employees", empId), {
      isApproved: true,
      status: 'shift',
      isBlocked: false,
      approvedAt: serverTimestamp(),
      approvedBy: adminEmail
    });
    console.log('✅ Employee approved:', empId);
    loadEmployeesFromAPI();
  } catch (err) {
    console.error("Approve error:", err);
    alert("Failed to approve employee.");
  }
}

async function rejectEmployee(empId) {
  try {
    await updateDoc(doc(db, "employees", empId), {
      isApproved: false,
      status: 'absent',
      isBlocked: true,
      rejectedAt: serverTimestamp(),
      rejectedBy: adminEmail
    });
    console.log('❌ Employee rejected:', empId);
    loadEmployeesFromAPI();
  } catch (err) {
    console.error("Reject error:", err);
    alert("Failed to reject employee.");
  }
}

async function deleteSelected() {
  if (!selectedIds.size) {
    alert("Select at least one employee.");
    return;
  }
  if (!confirm(`Delete ${selectedIds.size} employee(s)?`)) return;

  try {
    const batch = writeBatch(db);
    selectedIds.forEach(id => {
      batch.delete(doc(db, "employees", id));
    });
    await batch.commit();
    selectedIds.clear();
    loadEmployeesFromAPI();
  } catch (err) {
    console.error("Delete error:", err);
    alert("Failed to delete employees.");
  }
}

function toggleRowSelection(id) {
  if (selectedIds.has(id)) selectedIds.delete(id);
  else selectedIds.add(id);
  renderEmployees();
}

async function loadWarehousesForSuperAdmin() {
  if (!isSuperAdmin) return;
  
  try {
    const snap = await getDocs(collection(db, "warehouses"));
    allWarehouses = [];
    snap.forEach(doc => {
      allWarehouses.push({ id: doc.id, ...doc.data() });
    });
    
    warehouseSelect.innerHTML = allWarehouses.map(wh => 
      `<option value="${wh.id}">${wh.name} (${wh.id})</option>`
    ).join('');
    
    warehouseSelect.style.display = 'inline-block';
    
    if (allWarehouses.length > 0) {
      loadWarehouseCode(allWarehouses[0].id);
    }
    
    warehouseSelect.addEventListener('change', function() {
      loadWarehouseCode(this.value);
    });
  } catch (err) {
    console.error("Load warehouses error:", err);
  }
}

async function loadWarehouseCode(warehouseId) {
  try {
    const docSnap = await getDoc(doc(db, "warehouses", warehouseId));
    if (docSnap.exists()) {
      currentWarehouseData = { id: warehouseId, ...docSnap.data() };
      displayCode();
    }
  } catch (err) {
    console.error("Load code error:", err);
  }
}

function displayCode() {
  if (!currentWarehouseData) return;
  
  const code = currentWarehouseData.secretCode || '123456';
  const lastUpdate = currentWarehouseData.lastCodeUpdate;
  const updatedBy = currentWarehouseData.updatedBy || '';
  
  if (codeVisible) {
    codeDisplay.textContent = code;
    toggleCodeBtn.innerHTML = '<i class="fa-regular fa-eye-slash"></i> Hide Code';
  } else {
    codeDisplay.textContent = '••••••';
    toggleCodeBtn.innerHTML = '<i class="fa-regular fa-eye"></i> Show Code';
  }
  
  if (lastUpdate) {
    codeLastUpdate.textContent = `Last updated: ${formatDateTime(lastUpdate)}${updatedBy ? ` by ${updatedBy}` : ''}`;
  } else {
    codeLastUpdate.textContent = 'Using default code';
  }
}

toggleCodeBtn.addEventListener('click', function() {
  codeVisible = !codeVisible;
  displayCode();
});

changeCodeBtn.addEventListener('click', function() {
  if (!currentWarehouseData) {
    showToast('No warehouse selected', 'error');
    return;
  }
  
  const code = currentWarehouseData.secretCode || '123456';
  codeModalWarehouse.textContent = `Warehouse: ${currentWarehouseData.name || 'Unknown'} (${currentWarehouseData.id})`;
  currentCodeInput.value = code;
  newSecretCode.value = '';
  confirmSecretCode.value = '';
  codeModal.classList.add('active');
});

function closeCodeModal() {
  codeModal.classList.remove('active');
}

saveCodeBtn.addEventListener('click', async function() {
  const newCode = newSecretCode.value.trim();
  const confirmCode = confirmSecretCode.value.trim();
  
  if (!newCode || newCode.length < 4) {
    showToast('Code must be at least 4 characters', 'error');
    return;
  }
  
  if (newCode !== confirmCode) {
    showToast('Codes do not match', 'error');
    return;
  }
  
  if (!currentWarehouseData) {
    showToast('No warehouse selected', 'error');
    return;
  }
  
  try {
    this.disabled = true;
    this.textContent = 'Saving...';
    
    await updateDoc(doc(db, "warehouses", currentWarehouseData.id), {
      secretCode: newCode,
      lastCodeUpdate: serverTimestamp(),
      updatedBy: adminEmail
    });
    
    currentWarehouseData.secretCode = newCode;
    currentWarehouseData.lastCodeUpdate = new Date();
    currentWarehouseData.updatedBy = adminEmail;
    
    showToast('✅ Secret code updated successfully!', 'success');
    closeCodeModal();
    displayCode();
  } catch (err) {
    console.error("Update code error:", err);
    showToast('❌ Failed to update code', 'error');
  } finally {
    this.disabled = false;
    this.textContent = 'Save New Code';
  }
});

codeModal.addEventListener('click', function(e) {
  if (e.target === codeModal) {
    closeCodeModal();
  }
});

async function initSecretCode() {
  if (isSuperAdmin) {
    await loadWarehousesForSuperAdmin();
  } else if (adminWarehouseId && adminWarehouseId !== 'all') {
    await loadWarehouseCode(adminWarehouseId);
  }
}

employeeSearch.addEventListener("input", applySearch);
deleteBtn.addEventListener("click", deleteSelected);

selectAll.addEventListener("change", () => {
  const filtered = employees.filter(e => {
    if (!searchTerm) return true;
    const haystack = [e.employeeId, e.name, e.email, e.phone, e.warehouse, e.status]
      .filter(Boolean).join(" ").toLowerCase();
    return haystack.includes(searchTerm);
  });

  if (selectAll.checked) {
    filtered.forEach(e => selectedIds.add(e.id));
  } else {
    filtered.forEach(e => selectedIds.delete(e.id));
  }
  renderEmployees();
});

employeeTableBody.addEventListener("change", (e) => {
  const select = e.target.closest("[data-change-status]");
  if (select) changeStatus(select.dataset.changeStatus, select.value);
});

employeeTableBody.addEventListener("click", (e) => {
  const check = e.target.closest(".row-checkbox");
  const approveBtn = e.target.closest("[data-approve]");
  const rejectBtn = e.target.closest("[data-reject]");
  const row = e.target.closest("tr");
  const checkInput = row?.querySelector(".row-checkbox");

  if (check) {
    toggleRowSelection(check.dataset.employeeId);
    return;
  }

  if (approveBtn) {
    approveEmployee(approveBtn.dataset.approve);
    return;
  }

  if (rejectBtn) {
    rejectEmployee(rejectBtn.dataset.reject);
    return;
  }

  if (row && checkInput && !e.target.closest("button") && !e.target.closest("select")) {
    toggleRowSelection(checkInput.dataset.employeeId);
  }
});

function updateUIBasedOnRole() {
  const label = document.querySelector('.admin-title') || document.querySelector('.admin-label');
  if (!label) return;

  if (isSuperAdmin) {
    label.textContent = '🔑 Super Admin - All Warehouses';
    label.style.color = '#00C76A';
  } else {
    label.textContent = `👤 Admin - ${adminData.warehouseName || 'Warehouse'}`;
    label.style.color = '#8A8A98';
  }
  
  if (!isSuperAdmin) {
    if (deleteBtn) deleteBtn.style.display = 'none';
    if (selectAll) selectAll.style.display = 'none';
  }
}

updateUIBasedOnRole();
initSecretCode();
loadEmployeesFromAPI();
setInterval(loadEmployeesFromAPI, 30000);

console.log('🚀 Employee Dashboard Ready');