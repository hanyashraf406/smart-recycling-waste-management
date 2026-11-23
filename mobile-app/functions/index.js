const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require('cors')({ origin: true });

admin.initializeApp();

// ========== USERS ==========
exports.getAllUsers = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("users").get();
      const users = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { users } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

exports.blockUser = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { userId } = req.body.data || req.body;
      await admin.firestore().collection("users").doc(userId).update({ isBlocked: true });
      res.json({ result: { success: true } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

exports.unblockUser = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { userId } = req.body.data || req.body;
      await admin.firestore().collection("users").doc(userId).update({ isBlocked: false });
      res.json({ result: { success: true } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== EMPLOYEES ==========
exports.getAllEmployees = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("employees").get();
      const employees = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { employees } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

exports.getEmployee = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { employeeId } = req.body.data || req.body;
      const doc = await admin.firestore().collection("employees").doc(employeeId).get();
      res.json({ result: { id: doc.id, ...doc.data() } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== PROCESSES ==========
exports.getAllProcesses = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("recycling_processes").get();
      const processes = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { processes } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== WAREHOUSES ==========
exports.getAllWarehouses = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("warehouses").get();
      const warehouses = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { warehouses } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== REPORTS ==========
exports.getAllReports = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("reports").get();
      const reports = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { reports } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

exports.approveReport = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const { reportId, employeeId } = req.body.data || req.body;
      await admin.firestore().collection("reports").doc(reportId).update({
        status: "approved",
        approvedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      res.json({ result: { success: true } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== REVIEWS ==========
exports.getAllReviews = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("reviews").get();
      const reviews = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { reviews } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== STATISTICS ==========
exports.getStatistics = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      res.json({ result: { success: true } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== MATERIALS ==========
exports.getAllMaterials = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const snapshot = await admin.firestore().collection("materials").get();
      const materials = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json({ result: { materials } });
    } catch (error) {
      res.status(500).json({ error: { message: error.message } });
    }
  });
});

// ========== HEALTH ==========
exports.health = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    res.json({ result: { status: "ok" } });
  });
});

// ========== PASSWORD RESET ==========
exports.resetPasswordV2 = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      const data = req.body.data || req.body;
      const email = data.email;
      const newPassword = data.newPassword;

      if (!email || !newPassword) {
        res.status(400).json({
          error: {
            status: "INVALID_ARGUMENT",
            message: "Email and password required"
          }
        });
        return;
      }

      if (newPassword.length < 6) {
        res.status(400).json({
          error: {
            status: "INVALID_ARGUMENT",
            message: "Password must be at least 6 characters"
          }
        });
        return;
      }

      const user = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(user.uid, { password: newPassword });

      console.log("SUCCESS for:", email);
      res.json({ result: { success: true, message: "Password updated" } });
    } catch (error) {
      console.error("ERROR:", error.message);
      res.status(500).json({
        error: {
          status: "INTERNAL",
          message: error.message
        }
      });
    }
  });
});