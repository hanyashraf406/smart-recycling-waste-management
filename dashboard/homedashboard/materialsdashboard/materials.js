import { db } from "../../firebase-config.js";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  serverTimestamp,
  writeBatch
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";

// ✅ قراءة بيانات الأدمن من localStorage
const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';

console.log('👤 Admin Role:', adminData.role);
console.log('🏭 Warehouse ID:', adminWarehouseId);
console.log('🔑 Is Super Admin:', isSuperAdmin);

const materialsTableBody = document.querySelector("#materialTable tbody");
const materialForm = document.getElementById("materialForm");
const resetMaterialFormButton = document.getElementById("resetMaterialForm");
const materialFormMessage = document.getElementById("materialFormMessage");
const searchInput = document.getElementById("search");
const statusFilter = document.getElementById("statusFilter");
const clearFiltersButton = document.getElementById("clearFilters");
const exportButton = document.getElementById("exportBtn");
const resultCount = document.getElementById("resultCount");
const metrics = {
  total: document.querySelector('[data-metric="total"]'),
  active: document.querySelector('[data-metric="active"]'),
  inactive: document.querySelector('[data-metric="inactive"]')
};

let materialsRecords = [];

function normalizeText(value) {
  return String(value ?? "").trim();
}

function classifyStatus(status) {
  return normalizeText(status).toLowerCase() === "inactive" ? "inactive" : "active";
}

function updateMetrics(records) {
  metrics.total.textContent = records.length;
  metrics.active.textContent = records.filter((r) => classifyStatus(r.status) === "active").length;
  metrics.inactive.textContent = records.filter((r) => classifyStatus(r.status) === "inactive").length;
}

function getFilteredRecords() {
  const searchTerm = searchInput.value.trim().toLowerCase();
  const statusTerm = statusFilter.value;

  return materialsRecords.filter((record) => {
    const matchesSearch = !searchTerm || [
      record.materialId, record.name, record.type, record.status
    ].join(" ").toLowerCase().includes(searchTerm);

    const matchesStatus = statusTerm === "all" || classifyStatus(record.status) === statusTerm;
    return matchesSearch && matchesStatus;
  });
}

function getMaterialIconPath(type) {
  const typeLower = String(type || "").toLowerCase();
  if (typeLower === "plastic") return "../assets/plastic.svg";
  if (typeLower === "glass") return "../assets/glass.svg";
  if (typeLower === "cans") return "../assets/cans.svg";
  return "../assets/matierial.svg";
}

function renderRecords() {
  const filteredRecords = getFilteredRecords();
  materialsTableBody.innerHTML = "";

  if (filteredRecords.length === 0) {
    materialsTableBody.innerHTML = `<tr><td colspan="6" class="empty-state">No material records found.</td></tr>`;
    resultCount.textContent = "No materials found.";
    return;
  }

  filteredRecords.forEach((record) => {
    const statusClass = classifyStatus(record.status);
    const badgeClass = statusClass === "active" ? "status-badge active" : "status-badge inactive";
    const iconPath = getMaterialIconPath(record.type);

    // ✅ زرار Delete يظهر للسوبر أدمن فقط
    const deleteButton = isSuperAdmin 
      ? `<button type="button" class="row-action" data-delete-record="${record.id}">Delete</button>`
      : '';

    materialsTableBody.insertAdjacentHTML("beforeend", `
      <tr>
        <td>${record.materialId}</td>
        <td><img src="${iconPath}" alt="${record.type}" class="material-type-icon"></td>
        <td>${record.name || record.type || '-'}</td>
        <td><span class="${badgeClass}">${record.status || 'Active'}</span></td>
        <td>${record.note || '-'}</td>
        <td>${deleteButton}</td>
      </tr>
    `);
  });

  resultCount.textContent = `Showing ${filteredRecords.length} of ${materialsRecords.length} materials`;
}

// ✅ تحميل المواد من Firestore مباشرة
async function loadMaterialsFromFirestore() {
  try {
    resultCount.textContent = "Loading materials...";
    const materialsSnap = await getDocs(collection(db, "materials"));
    
    if (materialsSnap.empty) {
      materialsRecords = [];
      resultCount.textContent = "No materials found.";
      updateMetrics(materialsRecords);
      renderRecords();
      return;
    }
    
    materialsRecords = materialsSnap.docs.map(doc => ({
      id: doc.id,
      materialId: doc.data().materialId || doc.id,
      name: doc.data().name || doc.data().type,
      type: doc.data().type,
      status: doc.data().status || 'Active',
      note: doc.data().note || '',
      pointsPerKg: doc.data().pointsPerKg || 100,
      sizes: doc.data().sizes || []
    }));
    
    updateMetrics(materialsRecords);
    renderRecords();
    resultCount.textContent = `Loaded ${materialsRecords.length} materials`;
  } catch (error) {
    console.error("Failed to load materials:", error);
    resultCount.textContent = "Unable to load materials.";
    materialsTableBody.innerHTML = `<tr><td colspan="6" class="empty-state">Failed to load materials.</td></tr>`;
  }
}

// ✅ حفظ مادة جديدة - للسوبر أدمن فقط
if (materialForm) {
  materialForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    
    // ✅ منع الأدمن العادي من الحفظ
    if (!isSuperAdmin) {
      setFormMessage("Only Super Admin can add materials.", "error");
      return;
    }

    const type = normalizeText(document.getElementById("type").value);
    const status = normalizeText(document.getElementById("status").value) || "Active";
    const note = normalizeText(document.getElementById("note").value);

    if (!type) return setFormMessage("Type is required.", "error");

    const sizes = [];
    for (let i = 1; i <= 3; i++) {
      const sizeName = normalizeText(document.getElementById(`size${i}Name`)?.value);
      const sizeWeight = parseInt(document.getElementById(`size${i}Weight`)?.value) || 0;
      const sizePoints = parseInt(document.getElementById(`size${i}Points`)?.value) || 0;
      
      if (sizeName && sizeWeight > 0) {
        sizes.push({
          sizeId: `${type.toLowerCase()}_${sizeName.toLowerCase()}`,
          name: `${sizeName} ${type}`,
          weightGrams: sizeWeight,
          points: sizePoints,
          image: `${type.toLowerCase()}_${sizeName.toLowerCase()}.png`
        });
      }
    }

    const iconMap = { "Plastic": "🥤", "Glass": "🥃", "Cans": "🥫" };
    const icon = iconMap[type] || "📦";

    try {
      const countersRef = doc(db, "counters", "counters");
      const countersDoc = await getDoc(countersRef);
      
      let nextMaterialId = 1;
      if (countersDoc.exists()) {
        const data = countersDoc.data();
        nextMaterialId = (data.lastMaterialId || 3) + 1;
        await updateDoc(countersRef, { lastMaterialId: nextMaterialId });
      } else {
        await setDoc(countersRef, { 
          lastMaterialId: 1, 
          lastUserId: 0, 
          lastEmployeeId: 0, 
          lastProcessId: 0, 
          lastWarehouseId: 7 
        });
      }
      
      const generatedId = `M-${nextMaterialId.toString().padStart(3, '0')}`;
      
      // ✅ حفظ المادة الجديدة
      await setDoc(doc(db, "materials", generatedId), {
        materialId: generatedId,
        type: type.toLowerCase(),
        name: type,
        status,
        note,
        icon: icon,
        pointsPerKg: 100,
        sizes: sizes,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      });

      // ✅ إنشاء مخزون مبدئي للمادة الجديدة لجميع الموظفين
      const employeesSnap = await getDocs(collection(db, "employees"));
      if (employeesSnap.docs.length > 0) {
        const batch = writeBatch(db);
        
        employeesSnap.docs.forEach(empDoc => {
          const inventoryRef = doc(db, "inventory", `${empDoc.id}_${type.toLowerCase()}`);
          batch.set(inventoryRef, {
            employeeId: empDoc.id,
            warehouseId: empDoc.data().warehouseId || '',
            type: type.toLowerCase(),
            weight: 0.0,
            lastUpdated: serverTimestamp()
          });
        });
        
        await batch.commit();
        console.log(`✅ Inventory initialized for new material: ${type}`);
      }

      clearForm();
      setFormMessage(`Material saved as ${generatedId}!`, "success");
      loadMaterialsFromFirestore();
    } catch (error) {
      console.error("Failed to save material", error);
      setFormMessage("Unable to save the material.", "error");
    }
  });
}

// ✅ تحديث الواجهة حسب الصلاحية
function updateUIBasedOnRole() {
  const adminLabel = document.querySelector('.admin-label') || document.querySelector('.admin-title');
  if (adminLabel) {
    if (isSuperAdmin) {
      adminLabel.textContent = '🔑 Super Admin - All Warehouses';
      adminLabel.style.color = '#00C76A';
    } else {
      adminLabel.textContent = `👤 Admin - ${adminData.warehouseName || 'Warehouse'}`;
      adminLabel.style.color = '#8A8A98';
    }
  }
  
  // ✅ إخفاء الفورم عن الأدمن العادي
  const formPanel = document.querySelector('.form-panel');
  if (formPanel && !isSuperAdmin) {
    formPanel.style.display = 'none';
  }
  
  if (resetMaterialFormButton && !isSuperAdmin) {
    resetMaterialFormButton.style.display = 'none';
  }
  
  if (exportButton) {
    exportButton.style.display = 'none';
  }
  
  console.log('✅ Materials UI Updated - Super Admin:', isSuperAdmin);
}

if (resetMaterialFormButton) {
  resetMaterialFormButton.addEventListener("click", clearForm);
}

searchInput.addEventListener("input", renderRecords);
statusFilter.addEventListener("change", renderRecords);
clearFiltersButton.addEventListener("click", () => {
  searchInput.value = "";
  statusFilter.value = "all";
  renderRecords();
});

materialsTableBody.addEventListener("click", (event) => {
  const button = event.target.closest("[data-delete-record]");
  if (!button) return;
  if (!isSuperAdmin) {
    alert("Only Super Admin can delete materials.");
    return;
  }
  if (!confirm("Delete this material record?")) return;

  deleteDoc(doc(db, "materials", button.dataset.deleteRecord))
    .then(() => loadMaterialsFromFirestore())
    .catch((error) => {
      console.error("Failed to delete material", error);
      alert("Unable to delete the material right now.");
    });
});

function setFormMessage(message, tone = "info") {
  if (!materialFormMessage) return;
  materialFormMessage.textContent = message;
  materialFormMessage.dataset.tone = tone;
}

function clearForm() {
  document.getElementById("type").value = "";
  document.getElementById("status").value = "Active";
  document.getElementById("note").value = "";
  document.getElementById("size1Name").value = "Small";
  document.getElementById("size1Weight").value = 20;
  document.getElementById("size1Points").value = 2;
  document.getElementById("size2Name").value = "Medium";
  document.getElementById("size2Weight").value = 35;
  document.getElementById("size2Points").value = 3;
  document.getElementById("size3Name").value = "Large";
  document.getElementById("size3Weight").value = 50;
  document.getElementById("size3Points").value = 5;
  setFormMessage("");
}

updateUIBasedOnRole();
loadMaterialsFromFirestore();
setInterval(loadMaterialsFromFirestore, 30000);