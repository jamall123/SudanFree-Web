import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'SudanFree'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get haveAccount;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @skills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skills;

  /// No description provided for @hourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get hourlyRate;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @freelancer.
  ///
  /// In en, this message translates to:
  /// **'Freelancer'**
  String get freelancer;

  /// No description provided for @client.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get client;

  /// No description provided for @chooseRole.
  ///
  /// In en, this message translates to:
  /// **'Choose your role'**
  String get chooseRole;

  /// No description provided for @jobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get jobs;

  /// No description provided for @postJob.
  ///
  /// In en, this message translates to:
  /// **'Post a Job'**
  String get postJob;

  /// No description provided for @browseJobs.
  ///
  /// In en, this message translates to:
  /// **'Browse Jobs'**
  String get browseJobs;

  /// No description provided for @myJobs.
  ///
  /// In en, this message translates to:
  /// **'My Jobs'**
  String get myJobs;

  /// No description provided for @jobTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Title'**
  String get jobTitle;

  /// No description provided for @jobDescription.
  ///
  /// In en, this message translates to:
  /// **'Job Description'**
  String get jobDescription;

  /// No description provided for @budget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budget;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadline;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @proposals.
  ///
  /// In en, this message translates to:
  /// **'Proposals'**
  String get proposals;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @submitProposal.
  ///
  /// In en, this message translates to:
  /// **'Submit Proposal'**
  String get submitProposal;

  /// No description provided for @proposedPrice.
  ///
  /// In en, this message translates to:
  /// **'Proposed Price'**
  String get proposedPrice;

  /// No description provided for @deliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get deliveryTime;

  /// No description provided for @coverLetter.
  ///
  /// In en, this message translates to:
  /// **'Cover Letter'**
  String get coverLetter;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @uploadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Upload Receipt'**
  String get uploadReceipt;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @transactionRef.
  ///
  /// In en, this message translates to:
  /// **'Transaction Ref'**
  String get transactionRef;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data found'**
  String get noData;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @freelancers.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get freelancers;

  /// No description provided for @shops.
  ///
  /// In en, this message translates to:
  /// **'Shops'**
  String get shops;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @noPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPosts;

  /// No description provided for @beFirstToShare.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share!'**
  String get beFirstToShare;

  /// No description provided for @followToSeePosts.
  ///
  /// In en, this message translates to:
  /// **'Follow workers and shops to see their posts'**
  String get followToSeePosts;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPost;

  /// No description provided for @newUser.
  ///
  /// In en, this message translates to:
  /// **'🆕 New User'**
  String get newUser;

  /// No description provided for @newUserWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ This is a new freelancer without ratings\n\n• Verify their identity and reliability\n• Do not transfer any money in advance\n• Be careful sharing sensitive info'**
  String get newUserWarning;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Warning'**
  String get warning;

  /// No description provided for @lowRatingWarning.
  ///
  /// In en, this message translates to:
  /// **'⛔ This user has a low rating ({rating} ⭐)\n\n• Exercise extreme caution\n• Do not send money in advance\n• Verify all details'**
  String lowRatingWarning(Object rating);

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'💡 Reminder'**
  String get reminder;

  /// No description provided for @normalUserReminder.
  ///
  /// In en, this message translates to:
  /// **'• Agree on price before starting\n• Keep proof of agreement'**
  String get normalUserReminder;

  /// No description provided for @openWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get openWhatsApp;

  /// No description provided for @noWorksYet.
  ///
  /// In en, this message translates to:
  /// **'No works yet'**
  String get noWorksYet;

  /// No description provided for @addWork.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add new work'**
  String get addWork;

  /// No description provided for @loadingReviews.
  ///
  /// In en, this message translates to:
  /// **'Loading reviews...'**
  String get loadingReviews;

  /// No description provided for @reviewsError.
  ///
  /// In en, this message translates to:
  /// **'Error loading reviews'**
  String get reviewsError;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviews;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @platformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Freelance platform in Sudan'**
  String get platformSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our Terms and Privacy Policy'**
  String get agreeToTerms;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @clientAccount.
  ///
  /// In en, this message translates to:
  /// **'Client Account'**
  String get clientAccount;

  /// No description provided for @editProfileUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile / Upgrade Account'**
  String get editProfileUpgrade;

  /// No description provided for @editStore.
  ///
  /// In en, this message translates to:
  /// **'Edit Store'**
  String get editStore;

  /// No description provided for @reportStore.
  ///
  /// In en, this message translates to:
  /// **'Report Store'**
  String get reportStore;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add new product'**
  String get addProduct;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @emptyStoreOwner.
  ///
  /// In en, this message translates to:
  /// **'Store is empty, start adding products'**
  String get emptyStoreOwner;

  /// No description provided for @emptyStoreVisitor.
  ///
  /// In en, this message translates to:
  /// **'No products available currently'**
  String get emptyStoreVisitor;

  /// No description provided for @storeInfo.
  ///
  /// In en, this message translates to:
  /// **'Store Info'**
  String get storeInfo;

  /// No description provided for @storeCategory.
  ///
  /// In en, this message translates to:
  /// **'Store Category'**
  String get storeCategory;

  /// No description provided for @aboutStore.
  ///
  /// In en, this message translates to:
  /// **'About Store'**
  String get aboutStore;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @undefined.
  ///
  /// In en, this message translates to:
  /// **'Undefined'**
  String get undefined;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @coverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover Photo'**
  String get coverPhoto;

  /// No description provided for @storePhoto.
  ///
  /// In en, this message translates to:
  /// **'Store Photo'**
  String get storePhoto;

  /// No description provided for @viewImage.
  ///
  /// In en, this message translates to:
  /// **'View Image'**
  String get viewImage;

  /// No description provided for @changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get changeImage;

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get uploadingImage;

  /// No description provided for @imageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Image updated successfully'**
  String get imageUpdated;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get imageUploadFailed;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to SudanFree!'**
  String get welcome;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account to start your journey'**
  String get signupSubtitle;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @reEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter password'**
  String get reEnterPassword;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsNotMatch;

  /// No description provided for @readTerms.
  ///
  /// In en, this message translates to:
  /// **'Read Terms'**
  String get readTerms;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @termsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms and Privacy'**
  String get termsConfirmTitle;

  /// No description provided for @termsConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'By clicking \'Accept\', you confirm your agreement to our Terms and Privacy Policy.'**
  String get termsConfirmContent;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get enterPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password too short'**
  String get passwordTooShort;

  /// No description provided for @profilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture'**
  String get profilePhoto;

  /// No description provided for @noWorkDisplayed.
  ///
  /// In en, this message translates to:
  /// **'No work displayed'**
  String get noWorkDisplayed;

  /// No description provided for @addReview.
  ///
  /// In en, this message translates to:
  /// **'Add your review'**
  String get addReview;

  /// No description provided for @reviewAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Review added successfully'**
  String get reviewAddedSuccessfully;

  /// No description provided for @loginToReview.
  ///
  /// In en, this message translates to:
  /// **'You must log in to add a review'**
  String get loginToReview;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details...'**
  String get viewDetails;

  /// No description provided for @completedJobs.
  ///
  /// In en, this message translates to:
  /// **'Completed Jobs'**
  String get completedJobs;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @safetyTipsTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety Tips'**
  String get safetyTipsTitle;

  /// No description provided for @protectYourself.
  ///
  /// In en, this message translates to:
  /// **'Protect Yourself from Fraud'**
  String get protectYourself;

  /// No description provided for @forFreelancers.
  ///
  /// In en, this message translates to:
  /// **'For Freelancers & Workers'**
  String get forFreelancers;

  /// No description provided for @forClients.
  ///
  /// In en, this message translates to:
  /// **'For Clients'**
  String get forClients;

  /// No description provided for @safetyTipAskDeposit.
  ///
  /// In en, this message translates to:
  /// **'Request Upfront Deposit'**
  String get safetyTipAskDeposit;

  /// No description provided for @safetyTipAskDepositDesc.
  ///
  /// In en, this message translates to:
  /// **'For remote work, ask for a 30-50% deposit before starting.'**
  String get safetyTipAskDepositDesc;

  /// No description provided for @safetyTipConfirmCall.
  ///
  /// In en, this message translates to:
  /// **'Verify via Phone Call'**
  String get safetyTipConfirmCall;

  /// No description provided for @safetyTipConfirmCallDesc.
  ///
  /// In en, this message translates to:
  /// **'After agreeing on WhatsApp, call the client directly to verify identity and seriousness.'**
  String get safetyTipConfirmCallDesc;

  /// No description provided for @safetyTipVerifyAddress.
  ///
  /// In en, this message translates to:
  /// **'Verify Address'**
  String get safetyTipVerifyAddress;

  /// No description provided for @safetyTipVerifyAddressDesc.
  ///
  /// In en, this message translates to:
  /// **'Request the full address and nearby landmarks before visiting.'**
  String get safetyTipVerifyAddressDesc;

  /// No description provided for @safetyTipKeepProof.
  ///
  /// In en, this message translates to:
  /// **'Keep Proof of Agreement'**
  String get safetyTipKeepProof;

  /// No description provided for @safetyTipKeepProofDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep screenshots of WhatsApp conversations as proof of agreement and price.'**
  String get safetyTipKeepProofDesc;

  /// No description provided for @safetyTipCheckReviews.
  ///
  /// In en, this message translates to:
  /// **'Check Reviews'**
  String get safetyTipCheckReviews;

  /// No description provided for @safetyTipCheckReviewsDesc.
  ///
  /// In en, this message translates to:
  /// **'Read reviews from previous clients before hiring a freelancer.'**
  String get safetyTipCheckReviewsDesc;

  /// No description provided for @safetyTipSeePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Check Portfolio'**
  String get safetyTipSeePortfolio;

  /// No description provided for @safetyTipSeePortfolioDesc.
  ///
  /// In en, this message translates to:
  /// **'View previous work photos to verify quality.'**
  String get safetyTipSeePortfolioDesc;

  /// No description provided for @safetyTipAgreePrice.
  ///
  /// In en, this message translates to:
  /// **'Agree on Price Upfront'**
  String get safetyTipAgreePrice;

  /// No description provided for @safetyTipAgreePriceDesc.
  ///
  /// In en, this message translates to:
  /// **'Agree on the full price before work starts and pay only half as a deposit.'**
  String get safetyTipAgreePriceDesc;

  /// No description provided for @safetyWarningDesc.
  ///
  /// In en, this message translates to:
  /// **'Do not send money to people you haven\'t worked with before without guarantees.'**
  String get safetyWarningDesc;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @verificationRequests.
  ///
  /// In en, this message translates to:
  /// **'Verification Requests'**
  String get verificationRequests;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @activeJobs.
  ///
  /// In en, this message translates to:
  /// **'Active Projects'**
  String get activeJobs;

  /// No description provided for @startProject.
  ///
  /// In en, this message translates to:
  /// **'Start Project'**
  String get startProject;

  /// No description provided for @acceptOffer.
  ///
  /// In en, this message translates to:
  /// **'Accept Offer'**
  String get acceptOffer;

  /// No description provided for @completeJob.
  ///
  /// In en, this message translates to:
  /// **'Complete Project'**
  String get completeJob;

  /// No description provided for @idVerification.
  ///
  /// In en, this message translates to:
  /// **'ID Verification'**
  String get idVerification;

  /// No description provided for @advancedVerification.
  ///
  /// In en, this message translates to:
  /// **'Advanced Verification'**
  String get advancedVerification;

  /// No description provided for @uploadIdCard.
  ///
  /// In en, this message translates to:
  /// **'Upload ID Card'**
  String get uploadIdCard;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get pendingReview;

  /// No description provided for @professionalPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Professional Portfolio'**
  String get professionalPortfolio;

  /// No description provided for @addProject.
  ///
  /// In en, this message translates to:
  /// **'Add Project'**
  String get addProject;

  /// No description provided for @searchSmartHint.
  ///
  /// In en, this message translates to:
  /// **'Search for skills, freelancers, locations...'**
  String get searchSmartHint;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String noResultsFor(Object query);

  /// No description provided for @popularSearches.
  ///
  /// In en, this message translates to:
  /// **'Popular Searches'**
  String get popularSearches;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
