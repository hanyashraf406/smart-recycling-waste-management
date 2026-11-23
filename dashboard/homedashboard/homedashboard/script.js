import { auth, db } from "../../firebase-config.js";
import { collection, onSnapshot, orderBy, query, getDocs, where, limit } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-firestore.js";
import { signOut } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";

// ✅ قراءة بيانات الأدمن من localStorage
const adminData = JSON.parse(localStorage.getItem('adminUser') || '{}');
const isSuperAdmin = adminData.role === 'super_admin';
const adminWarehouseId = adminData.warehouseId || 'all';

console.log('👤 Admin Role:', adminData.role);
console.log('🏭 Warehouse ID:', adminWarehouseId);
console.log('🔑 Is Super Admin:', isSuperAdmin);

// =============== DOM Elements ===============
const employeesCollection = collection(db, "employees");
const employeesQuery = query(employeesCollection, orderBy("createdAt", "desc"));

// =============== CHART ===============
let materialsChart = null;
let cachedMaterialsData = null;

async function getAllMaterialsList() {
  try {
    const materialsSnap = await getDocs(collection(db, "materials"));
    return materialsSnap.docs.map(doc => ({
      id: doc.id,
      type: doc.data().type,
      name: doc.data().name || doc.data().type,
      icon: doc.data().icon || '📦',
      color: doc.data().color || null
    }));
  } catch (e) {
    console.error('Error loading materials:', e);
    return [];
  }
}

async function loadApprovedReportsMaterials() {
  try {
    if (cachedMaterialsData) return cachedMaterialsData;
    
    const allMaterials = await getAllMaterialsList();
    
    const reportsSnap = await getDocs(query(
      collection(db, "reports"),
      orderBy("createdAt", "desc")
    ));
    
    let reports = reportsSnap.docs
      .map(doc => ({ id: doc.id, ...doc.data() }))
      .filter(r => {
        const status = (r.status || '').toLowerCase();
        return status === 'approved' || status === 'done' || status === 'completed';
      });
    
    if (!isSuperAdmin && adminWarehouseId !== 'all') {
      reports = reports.filter(r => r.warehouseId === adminWarehouseId);
    }
    
    const materialsMap = {};
    reports.forEach(report => {
      const mats = report.materials || {};
      Object.entries(mats).forEach(([type, weight]) => {
        materialsMap[type] = (materialsMap[type] || 0) + Number(weight || 0);
      });
    });
    
    allMaterials.forEach(mat => {
      if (!materialsMap[mat.type]) materialsMap[mat.type] = 0;
    });
    
    cachedMaterialsData = {
      materialsMap,
      allMaterials,
      totalWeight: Object.values(materialsMap).reduce((sum, w) => sum + w, 0),
      totalReports: reports.length
    };
    
    return cachedMaterialsData;
  } catch (e) {
    console.error('Error loading approved reports:', e);
    return { materialsMap: {}, allMaterials: [], totalWeight: 0, totalReports: 0 };
  }
}

async function updateChart() {
  const chartContext = document.getElementById('chart');
  if (!chartContext) return;
  
  const { materialsMap, allMaterials } = await loadApprovedReportsMaterials();
  
  if (materialsChart) materialsChart.destroy();
  
  const defaultColorPalette = [
    '#2196F3', '#FF9800', '#4CAF50', '#E91E63', '#9C27B0',
    '#00BCD4', '#FF5722', '#795548', '#607D8B', '#FFEB3B',
    '#8BC34A', '#03A9F4', '#F44336', '#009688', '#673AB7'
  ];
  
  const labels = [];
  const data = [];
  const backgroundColor = [];
  
  Object.entries(materialsMap).forEach(([type, weight], index) => {
    const mat = allMaterials.find(m => m.type === type);
    labels.push(mat?.name || type.charAt(0).toUpperCase() + type.slice(1));
    data.push(weight);
    
    if (mat?.color && mat.color.startsWith('#')) {
      backgroundColor.push(mat.color);
    } else {
      backgroundColor.push(defaultColorPalette[index % defaultColorPalette.length]);
    }
  });
  
  if (labels.length === 0) {
    labels.push('No Materials');
    data.push(1);
    backgroundColor.push('#E0E0E0');
  }
  
  materialsChart = new Chart(chartContext, {
    type: 'doughnut',
    data: {
      labels: labels,
      datasets: [{
        data: data,
        backgroundColor: backgroundColor,
        borderWidth: 2,
        borderColor: '#FFFFFF'
      }]
    },
    options: {
      cutout: '65%',
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          position: 'bottom',
          labels: { 
            boxWidth: 14,
            padding: 10,
            font: { size: 11 },
            usePointStyle: true
          }
        }
      }
    }
  });
}

// =============== LOAD USERS ===============
let users = [];

async function loadUsers() {
  try {
    users = [];
    
    if (isSuperAdmin && adminWarehouseId === 'all') {
      const usersSnap = await getDocs(query(collection(db, "users"), limit(200)));
      users = usersSnap.docs.map(doc => {
        const data = doc.data();
        return {
          id: data.displayId || doc.id?.slice(0, 8) || 'N/A',
          name: `${data.firstName || ''} ${data.lastName || ''}`.trim() || data.email?.split('@')[0] || 'N/A',
          email: data.email || 'N/A',
          points: data.points || 0,
          isBlocked: data.isBlocked || false
        };
      });
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
        limit(500)
      ));
      
      const uniqueUserIds = new Set();
      
      processesSnap.docs.forEach(doc => {
        const data = doc.data();
        if (data.employeeId && warehouseEmployeeIds.has(data.employeeId) && data.userId) {
          uniqueUserIds.add(data.userId);
        }
      });
      
      if (uniqueUserIds.size === 0) {
        processesSnap.docs.forEach(doc => {
          const data = doc.data();
          if (data.userId && (data.warehouseId === adminWarehouseId || data.warehouseName === adminData.warehouseName)) {
            uniqueUserIds.add(data.userId);
          }
        });
      }
      
      for (const userId of uniqueUserIds) {
        try {
          const userSnap = await getDocs(query(collection(db, "users"), where("userId", "==", userId)));
          if (!userSnap.empty) {
            const userData = userSnap.docs[0].data();
            users.push({
              id: userData.displayId || userId?.slice(0, 8) || 'N/A',
              name: `${userData.firstName || ''} ${userData.lastName || ''}`.trim() || userData.email?.split('@')[0] || 'N/A',
              email: userData.email || 'N/A',
              points: userData.points || 0,
              isBlocked: userData.isBlocked || false
            });
          }
        } catch (e) {
          console.error('Error loading user:', userId, e);
        }
      }
    }
    
    renderUsersTable();
    updateUsersStats();
  } catch (error) {
    console.error('Error loading users:', error);
    users = [];
    renderUsersTable();
  }
}

function renderUsersTable() {
  const usersTableBody = document.querySelector('#usersTable tbody');
  if (!usersTableBody) return;
  
  if (!users.length) {
    usersTableBody.innerHTML = `<tr><td colspan="5" class="empty-state">No users found for this warehouse</td></tr>`;
    return;
  }

  usersTableBody.innerHTML = users.map(user => `
    <tr>
      <td>${user.id}</td>
      <td>${user.name}</td>
      <td>${user.email}</td>
      <td>${user.points}</td>
      <td><span class="status ${user.isBlocked ? 'blocked' : 'active'}">${user.isBlocked ? 'Blocked' : 'Active'}</span></td>
    </tr>
  `).join('');
}

function updateUsersStats() {
  const totalUsersEl = document.getElementById('totalUsers');
  const activeUsersEl = document.getElementById('activeUsers');
  if (totalUsersEl) totalUsersEl.textContent = users.length;
  if (activeUsersEl) activeUsersEl.textContent = users.filter(u => !u.isBlocked).length;
}

// =============== EMPLOYEES ===============
let liveEmployees = [];
const empTable = document.querySelector("#employeeTable tbody");

function renderEmployees() {
  let filteredEmployees = liveEmployees;
  
  if (!isSuperAdmin && adminWarehouseId !== 'all') {
    filteredEmployees = liveEmployees.filter(e => {
      return e.warehouseId === adminWarehouseId;
    });
  }
  
  if (!filteredEmployees.length) {
    empTable.innerHTML = `<tr><td colspan="6" class="empty-state">No employees found</td></tr>`;
    updateEmployeeStats(0);
    return;
  }

  empTable.innerHTML = filteredEmployees.map((emp) => `
    <tr>
      <td><strong>${emp.displayId || 'N/A'}</strong></td>
      <td>${emp.name || "-"}</td>
      <td>${emp.email || "-"}</td>
      <td>${emp.warehouse || emp.warehouseName || "-"}</td>
      <td>${emp.totalScans || 0}</td>
      <td><span class="status ${emp.statusClass || 'shift'}">${emp.statusText || 'Active'}</span></td>
    </tr>
  `).join("");

  updateEmployeeStats(filteredEmployees.length);
}

function updateEmployeeStats(count) {
  const totalEmployeesEl = document.getElementById('totalEmployees');
  if (totalEmployeesEl) totalEmployeesEl.textContent = count;
}

// =============== RECYCLING PROCESSES ===============
let recycling = [];
let approvedTotalWeight = 0;

async function loadRecyclingProcesses() {
  try {
    let allProcesses = [];
    
    if (isSuperAdmin && adminWarehouseId === 'all') {
      const processesSnap = await getDocs(query(
        collection(db, "recycling_processes"),
        orderBy("scannedAt", "desc"),
        limit(50)
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
        limit(200)
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
    
    recycling = allProcesses.map(proc => {
      let dateObj = null;
      const scannedAt = proc.scannedAt;
      
      if (scannedAt) {
        if (scannedAt.seconds) dateObj = new Date(scannedAt.seconds * 1000);
        else if (scannedAt._seconds) dateObj = new Date(scannedAt._seconds * 1000);
        else if (scannedAt.toDate) dateObj = scannedAt.toDate();
      }
      
      if (!dateObj || isNaN(dateObj.getTime())) dateObj = new Date();
      
      return {
        id: proc.processId || proc.id?.slice(0, 8) || 'N/A',
        user: proc.userDisplayId || proc.userId || 'N/A',
        points: proc.totalPoints || 0,
        date: dateObj.toLocaleDateString('en-GB'),
        time: dateObj.toLocaleTimeString('en-GB', { hour12: false }),
        status: (proc.status || 'done').toLowerCase(),
        weight: Number(proc.totalWeightKg || 0)
      };
    });
    
    renderRecyclingTable();
    updateTotalProcesses();
  } catch (error) {
    console.error('Error loading recycling processes:', error);
    recycling = [];
    renderRecyclingTable();
  }
}

const recTable = document.querySelector("#recycleTable tbody");

function renderRecyclingTable() {
  if (!recTable) return;
  
  if (!recycling.length) {
    recTable.innerHTML = `<tr><td colspan="6" class="empty-state">No recycling processes found</td></tr>`;
    return;
  }

  recTable.innerHTML = recycling.slice(0, 20).map((item) => `
    <tr>
      <td>${item.id}</td>
      <td>${item.user}</td>
      <td>${item.points}</td>
      <td>${item.date}</td>
      <td>${item.time}</td>
      <td><span class="status ${item.status}">${item.status}</span></td>
    </tr>
  `).join("");
}

function updateTotalProcesses() {
  const totalProcessesEl = document.getElementById('totalProcesses');
  if (totalProcessesEl) totalProcessesEl.textContent = recycling.length;
  
  const totalWeightEl = document.getElementById('totalWeight');
  if (totalWeightEl) {
    if (approvedTotalWeight > 0) {
      if (approvedTotalWeight >= 1000) {
        totalWeightEl.textContent = `${(approvedTotalWeight / 1000).toFixed(2)} T`;
      } else {
        totalWeightEl.textContent = `${approvedTotalWeight.toFixed(2)} kg`;
      }
    } else {
      totalWeightEl.textContent = '0 kg';
    }
  }
}

// =============== EMPLOYEES LISTENER ===============
onSnapshot(employeesQuery, (snapshot) => {
  liveEmployees = snapshot.docs.map((snapshotDoc) => {
    const data = snapshotDoc.data();
    return {
      id: snapshotDoc.id,
      displayId: data.displayId || 'N/A',
      name: `${data.firstName || ''} ${data.lastName || ''}`.trim() || data.email?.split('@')[0] || 'N/A',
      email: data.email || 'N/A',
      warehouse: data.warehouseName || data.warehouse || 'N/A',
      warehouseId: data.warehouseId || '',
      totalScans: data.totalScans || 0,
      statusClass: data.isBlocked ? 'absent' : 'shift',
      statusText: data.isBlocked ? 'Blocked' : 'Active'
    };
  });

  renderEmployees();
});

// =============== INIT ===============
function updateUIBasedOnRole() {
  const adminLabel = document.getElementById('adminLabel') || document.querySelector('.admin-label');
  if (adminLabel) {
    if (isSuperAdmin) {
      adminLabel.textContent = '🔑 Super Admin - All Warehouses';
      adminLabel.style.color = '#00C76A';
    } else {
      adminLabel.textContent = `👤 Admin - ${adminData.warehouseName || 'Warehouse'}`;
      adminLabel.style.color = '#8A8A98';
    }
  }
}

async function loadAllData() {
  console.log('🚀 Loading all dashboard data...');
  
  cachedMaterialsData = null;
  
  const { totalWeight } = await loadApprovedReportsMaterials();
  approvedTotalWeight = totalWeight;
  
  await updateChart();
  await loadRecyclingProcesses();
  await loadUsers();
  updateUIBasedOnRole();
  
  console.log('✅ Dashboard data loaded');
}

loadAllData();

// =============== LOGOUT ===============
async function logout() {
  try {
    await signOut(auth);
  } catch (e) {
    console.error('Logout error:', e);
  } finally {
    localStorage.removeItem('adminUser');
    window.location.href = "../../login.html";
  }
}

document.querySelector('[data-sign-out]')?.addEventListener('click', (e) => {
  e.preventDefault();
  logout();
});

setInterval(loadAllData, 30000);