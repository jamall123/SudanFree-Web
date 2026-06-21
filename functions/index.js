const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.checkJobMilestones = functions.firestore
  .document('jobs/{jobId}')
  .onUpdate(async (change, context) => {
    const jobBefore = change.before.data();
    const jobAfter = change.after.data();
    const jobId = context.params.jobId;

    // Check if the job is already completed to avoid infinite loops
    if (jobAfter.status === 'completed' || jobAfter.status === 'cancelled') {
      return null;
    }

    // Ensure milestones array exists and isn't empty
    const milestones = jobAfter.milestones || [];
    if (milestones.length === 0) {
      return null;
    }

    // Check if ALL milestones are confirmed by the provider
    const allConfirmed = milestones.every(
      (m) => m.status === 'confirmedByProvider' || m.isConfirmed === true
    );

    if (allConfirmed) {
      console.log(`Job ${jobId} has all milestones confirmed. Auto-completing...`);
      
      try {
        await admin.firestore().collection('jobs').doc(jobId).update({
          status: 'completed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`Job ${jobId} successfully marked as completed.`);
      } catch (error) {
        console.error(`Error auto-completing job ${jobId}:`, error);
      }
    }

    return null;
  });
