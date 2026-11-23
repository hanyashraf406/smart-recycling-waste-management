// api.js - استدعاءات API Firebase Cloud Functions

const API_URLS = {
  getAllUsers: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllUsers',
  getAllEmployees: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllEmployees',
  getEmployee: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getEmployee',
  getAllProcesses: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllProcesses',
  getAllWarehouses: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllWarehouses',
  getAllReports: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllReports',
  approveReport: 'https://us-central1-cach-6ebd3.cloudfunctions.net/approveReport',
  getAllReviews: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllReviews',
  getStatistics: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getStatistics',
  blockUser: 'https://us-central1-cach-6ebd3.cloudfunctions.net/blockUser',
  unblockUser: 'https://us-central1-cach-6ebd3.cloudfunctions.net/unblockUser',
  health: 'https://us-central1-cach-6ebd3.cloudfunctions.net/health',
  getAllMaterials: 'https://us-central1-cach-6ebd3.cloudfunctions.net/getAllMaterials'
};

async function callAPI(functionName, data = {}) {
  const url = API_URLS[functionName];
  if (!url) throw new Error(`Function ${functionName} not found`);
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ data: data })
    });
    
    const result = await response.json();
    
    if (result.error) {
      console.error('API Error:', result.error);
      throw new Error(result.error.message || 'API Error');
    }
    
    if (result.result && result.result.success === false) {
      console.error('API Error:', result.result.error);
      throw new Error(result.result.error);
    }
    
    // Extract data from response
    if (result.result) {
      return result.result;
    }
    
    return result;
  } catch (error) {
    console.error('Network Error:', error);
    throw error;
  }
}

async function getAllUsers() { return callAPI('getAllUsers'); }
async function blockUser(userId) { return callAPI('blockUser', { userId }); }
async function unblockUser(userId) { return callAPI('unblockUser', { userId }); }
async function getAllEmployees() { return callAPI('getAllEmployees'); }
async function getEmployee(employeeId) { return callAPI('getEmployee', { employeeId }); }
async function getAllProcesses(filters = {}) { return callAPI('getAllProcesses', filters); }
async function getAllWarehouses() { return callAPI('getAllWarehouses'); }
async function getAllReports(filters = {}) { return callAPI('getAllReports', filters); }
async function approveReport(reportId, employeeId) { return callAPI('approveReport', { reportId, employeeId }); }
async function getAllReviews(filters = {}) { return callAPI('getAllReviews', filters); }
async function getStatistics(filters = {}) { return callAPI('getStatistics', filters); }
async function checkHealth() { return callAPI('health'); }
async function getAllMaterials() { return callAPI('getAllMaterials'); }

console.log('✅ API Module Loaded');