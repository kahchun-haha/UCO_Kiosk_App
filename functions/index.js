const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

// To configure, run the following command in your terminal:
// firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-app-password"
const gmailEmail = functions.config().gmail.email;
const gmailPassword = functions.config().gmail.password;

// Create a transporter object using the default SMTP transport
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

exports.sendEmailNotification = functions.https.onCall(async (data, context) => {
  // Ensure the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const userEmail = context.auth.token.email; // The email of the authenticated user
  const fillLevel = data.fillLevel; // The fill level passed from the app

  const mailOptions = {
    from: gmailEmail,
    to: userEmail, // Send the email to the currently logged-in user
    subject: "Kiosk Status Alert: Nearly Full!",
    text: `This is an automated message to inform you that the kiosk's fill level is currently at ${fillLevel}%. Please arrange for it to be serviced.`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: `Email sent to ${userEmail}` };
  } catch (error) {
    console.error("There was an error while sending the email:", error);
    throw new functions.https.HttpsError(
      "internal",
      "An error occurred while sending the email."
    );
  }
});