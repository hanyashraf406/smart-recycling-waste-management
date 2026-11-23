import { db } from "../../firebase-config.js";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  serverTimestamp,
  updateDoc,
  query,
  where,
  orderBy,
  limit
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

// ✅ قراءة بيانات الأدمن
const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';

console.log('👤 Role:', adminData.role, '| 🏭 Warehouse:', adminWarehouseId);
console.log('🔑 Is Super Admin:', isSuperAdmin);

const warehouseTableBody = document.querySelector("#warehouseTable tbody");
const warehouseForm = document.getElementById("warehouseForm");
const warehouseFormMessage = document.getElementById("warehouseFormMessage");
const searchInput = document.getElementById("search");
const statusFilter = document.getElementById("statusFilter");
const clearFiltersButton = document.getElementById("clearFilters");
const resultCount = document.getElementById("resultCount");
const metrics = {
  total: document.querySelector('[data-metric="total"]'),
  done: document.querySelector('[data-metric="done"]'),
  pending: document.querySelector('[data-metric="pending"]'),
  issue: document.querySelector('[data-metric="issue"]')
};

let warehouseRecords = [];
let allMaterials = [];

// ✅ تحميل المواد من Firestore
async function loadAllMaterials() {
  try {
    const materialsSnap = await getDocs(collection(db, "materials"));
    allMaterials = materialsSnap.docs.map(doc => ({
      id: doc.id,
      type: doc.data().type,
      name: doc.data().name || doc.data().type,
      icon: doc.data().icon || '📦',
      color: doc.data().color || null
    }));
    console.log('📋 Materials loaded:', allMaterials.map(m => m.name));
  } catch (e) {
    console.error('Error loading materials:', e);
    allMaterials = [];
  }
}

function normalizeText(value) {
  return String(value ?? "").trim();
}

function classifyStatus(status) {
  const v = normalizeText(status).toLowerCase();
  if (v.includes("done") || v.includes("complete") || v.includes("approved")) return "done";
  if (v.includes("pend")) return "pending";
  return "issue";
}

function formatLocalDate(ts) {
  if (ts?.toDate) return ts.toDate().toLocaleDateString("en-GB");
  if (ts?._seconds) return new Date(ts._seconds * 1000).toLocaleDateString("en-GB");
  if (ts?.seconds) return new Date(ts.seconds * 1000).toLocaleDateString("en-GB");
  return new Date().toLocaleDateString("en-GB");
}

function formatLocalTime(ts) {
  if (ts?.toDate) return ts.toDate().toLocaleTimeString("en-GB", { hour12: false });
  if (ts?._seconds) return new Date(ts._seconds * 1000).toLocaleTimeString("en-GB", { hour12: false });
  if (ts?.seconds) return new Date(ts.seconds * 1000).toLocaleTimeString("en-GB", { hour12: false });
  return new Date().toLocaleTimeString("en-GB", { hour12: false });
}

function toRecord(p) {
  const m = p.materialsWeight || {};
  return {
    firestoreId: p.id || p.processId,
    recordId: normalizeText(p.processId || p.id),
    employeeId: normalizeText(p.employeeDisplayId || p.employeeId),
    userId: normalizeText(p.userDisplayId || p.userId),
    materials: m,
    points: Number(p.totalPoints || 0),
    date: formatLocalDate(p.scannedAt),
    time: formatLocalTime(p.scannedAt),
    status: normalizeText(p.status || "Done"),
    warehouseId: p.warehouseId || '',
    warehouseName: p.warehouseName || '',
    scannedAt: p.scannedAt,
    employeeUid: p.employeeId || ''
  };
}

function updateMetrics(records) {
  metrics.total.textContent = records.length;
  metrics.done.textContent = records.filter(r => classifyStatus(r.status) === "done").length;
  metrics.pending.textContent = records.filter(r => classifyStatus(r.status) === "pending").length;
  metrics.issue.textContent = records.filter(r => classifyStatus(r.status) === "issue").length;
}

function getFilteredRecords() {
  const term = searchInput.value.trim().toLowerCase();
  const st = statusFilter.value;
  return warehouseRecords.filter(r => {
    const materialsText = Object.entries(r.materials || {})
      .map(([type, weight]) => `${type}:${weight}`)
      .join(" ");
    const searchText = [
      r.recordId, r.employeeId, r.userId, r.status, r.warehouseName, materialsText
    ].join(" ").toLowerCase();
    const matchSearch = !term || searchText.includes(term);
    const matchStatus = st === "all" || classifyStatus(r.status) === st;
    return matchSearch && matchStatus;
  });
}

function renderRecords() {
  const filtered = getFilteredRecords();
  warehouseTableBody.innerHTML = "";

  if (!filtered.length) {
    warehouseTableBody.innerHTML = `<tr><td colspan="9" class="empty-state">No records found.</td></tr>`;
    resultCount.textContent = warehouseRecords.length ? "No results." : "Waiting for data...";
    return;
  }

  filtered.forEach(r => {
    const sc = classifyStatus(r.status);
    const badge = sc === "done" ? "status-badge done" : sc === "pending" ? "status-badge pending" : "status-badge issue";

    let materialsHtml = '';
    const materialEntries = Object.entries(r.materials || {});
    
    if (materialEntries.length > 0) {
      materialsHtml = '<div class="materials-list">';
      materialEntries.forEach(([type, weight]) => {
        const mat = allMaterials.find(m => m.type === type);
        const name = mat?.name || type;
        const color = mat?.color || '#00C76A';
        const icon = mat?.icon || '📦';
        
        materialsHtml += `
          <div class="material-item" style="border-left: 3px solid ${color};">
            <span class="material-icon">${icon}</span>
            <span class="material-name">${name}</span>
            <span class="material-weight">${Number(weight).toFixed(1)}kg</span>
          </div>
        `;
      });
      materialsHtml += '</div>';
    } else {
      materialsHtml = '<span style="color:#8A8A98;">-</span>';
    }

    const deleteBtn = isSuperAdmin
      ? `<button type="button" class="row-action delete-record-btn" data-delete-record="${r.firestoreId}">🗑️</button>`
      : '';

    warehouseTableBody.insertAdjacentHTML("beforeend", `
      <tr>
        <td><strong>${r.recordId}</strong></td>
        <td>${r.employeeId || "-"}</td>
        <td>${r.userId || "-"}</td>
        <td class="materials-cell">${materialsHtml}</td>
        <td><span class="points-badge">⭐ ${r.points}</span></td>
        <td>${r.date || "-"}</td>
        <td>${r.time || "-"}</td>
        <td><span class="${badge}">${r.status || "Done"}</span></td>
        <td>${deleteBtn}</td>
      </tr>
    `);
  });

  resultCount.textContent = `Showing ${filtered.length} of ${warehouseRecords.length} records`;
}

async function loadProcessesFromFirestore() {
  try {
    resultCount.textContent = "Loading...";
    await loadAllMaterials();
    
    let allProcesses = [];
    
    if (isSuperAdmin && adminWarehouseId === 'all') {
      const processesSnap = await getDocs(query(
        collection(db, "recycling_processes"),
        orderBy("scannedAt", "desc"),
        limit(200)
      ));
      allProcesses = processesSnap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    } else {
      const employeesSnap = await getDocs(query(
        collection(db, "employees"),
        where("warehouseId", "==", adminWarehouseId)
      ));
      
      const warehouseEmployeeIds = new Set();
      employeesSnap.docs.forEach(doc => warehouseEmployeeIds.add(doc.id));
      
      const processesSnap = await getDocs(query(
        collection(db, "recycling_processes"),
        orderBy("scannedAt", "desc"),
        limit(300)
      ));
      
      allProcesses = processesSnap.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter(p => {
          if (p.employeeId && warehouseEmployeeIds.has(p.employeeId)) return true;
          if (p.warehouseId === adminWarehouseId) return true;
          if (p.warehouseName === adminData.warehouseName) return true;
          return false;
        });
    }
    
    warehouseRecords = allProcesses
      .map(toRecord)
      .sort((a, b) => (b.scannedAt?._seconds || b.scannedAt?.seconds || 0) - (a.scannedAt?._seconds || a.scannedAt?.seconds || 0));

    updateMetrics(warehouseRecords);
    renderRecords();
  } catch (e) {
    console.error('Error loading processes:', e);
    resultCount.textContent = "Unable to load.";
    warehouseTableBody.innerHTML = `<tr><td colspan="9" class="empty-state">Failed to connect.</td></tr>`;
  }
}

function updateFormVisibility() {
  const formPanel = document.querySelector('.form-panel');
  if (formPanel && !isSuperAdmin) {
    formPanel.style.display = 'none';
  }
  const resetBtn = document.getElementById("resetWarehouseForm");
  if (resetBtn && !isSuperAdmin) {
    resetBtn.style.display = 'none';
  }
}

if (warehouseForm) {
  warehouseForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    
    if (!isSuperAdmin) {
      warehouseFormMessage.textContent = "Only Super Admin can add records.";
      warehouseFormMessage.style.color = "#ff4d4f";
      return;
    }

    const employeeId = normalizeText(document.getElementById("employeeId")?.value || '');
    const userId = normalizeText(document.getElementById("userId")?.value || '');
    const points = Number(document.getElementById("points")?.value) || 0;
    const status = normalizeText(document.getElementById("status")?.value) || "Done";
    const note = normalizeText(document.getElementById("note")?.value || '');

    const dynamicMaterials = {};
    let totalWeight = 0;

    for (const mat of allMaterials) {
      const input = document.getElementById(`material_${mat.type}`);
      if (input) {
        const weight = Number(input.value) || 0;
        if (weight > 0) {
          dynamicMaterials[mat.type] = weight;
          totalWeight += weight;
        }
      }
    }

    if (Object.keys(dynamicMaterials).length === 0) {
      const glass = Number(document.getElementById("glass")?.value) || 0;
      const plastic = Number(document.getElementById("plastic")?.value) || 0;
      const cans = Number(document.getElementById("cans")?.value) || 0;
      if (glass > 0) { dynamicMaterials['glass'] = glass; totalWeight += glass; }
      if (plastic > 0) { dynamicMaterials['plastic'] = plastic; totalWeight += plastic; }
      if (cans > 0) { dynamicMaterials['cans'] = cans; totalWeight += cans; }
    }

    if (!employeeId || !userId) {
      warehouseFormMessage.textContent = "Employee ID and User ID required.";
      warehouseFormMessage.style.color = "#ff4d4f";
      return;
    }

    if (totalWeight <= 0) {
      warehouseFormMessage.textContent = "Please add at least one material with weight.";
      warehouseFormMessage.style.color = "#ff4d4f";
      return;
    }

    try {
      const id = await generateRecordId();

      await setDoc(doc(db, "recycling_processes", id), {
        processId: id,
        employeeId: employeeId,
        employeeDisplayId: employeeId,
        userId: userId,
        userDisplayId: userId,
        materialsWeight: dynamicMaterials,
        totalWeightKg: totalWeight,
        totalPoints: points,
        scannedAt: serverTimestamp(),
        status: status,
        note: note,
        warehouseId: adminData.warehouseId || adminWarehouseId,
        warehouseName: adminData.warehouseName || '',
      });

      warehouseForm.reset();
      warehouseFormMessage.textContent = `✅ ${id} saved successfully!`;
      warehouseFormMessage.style.color = "#00A85A";
      
      for (const mat of allMaterials) {
        const input = document.getElementById(`material_${mat.type}`);
        if (input) input.value = 0;
      }
      document.getElementById("glass") && (document.getElementById("glass").value = 0);
      document.getElementById("plastic") && (document.getElementById("plastic").value = 0);
      document.getElementById("cans") && (document.getElementById("cans").value = 0);
      document.getElementById("points") && (document.getElementById("points").value = 0);
      
      loadProcessesFromFirestore();
    } catch (err) {
      console.error("Save error:", err);
      warehouseFormMessage.textContent = "Save failed.";
      warehouseFormMessage.style.color = "#ff4d4f";
    }
  });
}

async function generateRecordId() {
  const ref = doc(db, "counters", "counters");
  const snap = await getDoc(ref);

  let next = 1;
  if (snap.exists()) {
    const d = snap.data();
    next = (d.lastProcessId || 0) + 1;
    await updateDoc(ref, { lastProcessId: next });
  } else {
    await setDoc(ref, {
      lastUserId: 0, lastEmployeeId: 0, lastProcessId: 1,
      lastMaterialId: 3, lastWarehouseId: 7
    });
  }
  return `RP-${String(next).padStart(3, '0')}`;
}

const resetBtn = document.getElementById("resetWarehouseForm");
if (resetBtn) {
  resetBtn.addEventListener("click", () => {
    warehouseForm.reset();
    for (const mat of allMaterials) {
      const input = document.getElementById(`material_${mat.type}`);
      if (input) input.value = 0;
    }
    if (warehouseFormMessage) warehouseFormMessage.textContent = "";
  });
}

searchInput.addEventListener("input", renderRecords);
statusFilter.addEventListener("change", renderRecords);
clearFiltersButton.addEventListener("click", () => {
  searchInput.value = "";
  statusFilter.value = "all";
  renderRecords();
});

const exportBtn = document.getElementById("exportBtn");
if (exportBtn) exportBtn.style.display = "none";

warehouseTableBody.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-delete-record]");
  if (!btn) return;
  if (!isSuperAdmin) { alert("Only Super Admin can delete records."); return; }
  if (!confirm("Delete this record?")) return;

  deleteDoc(doc(db, "recycling_processes", btn.dataset.deleteRecord))
    .then(() => loadProcessesFromFirestore())
    .catch(err => { console.error("Delete error:", err); alert("Delete failed."); });
});

function updateUIBasedOnRole() {
  const label = document.querySelector(".admin-label") || document.querySelector(".admin-title");
  if (label) {
    if (isSuperAdmin) {
      label.textContent = "🔑 Super Admin - All Warehouses";
      label.style.color = "#00C76A";
    } else {
      label.textContent = `👤 Admin - ${adminData.warehouseName || "Warehouse"}`;
      label.style.color = "#8A8A98";
    }
  }
  updateFormVisibility();
}

updateUIBasedOnRole();
loadProcessesFromFirestore();
setInterval(loadProcessesFromFirestore, 30000);