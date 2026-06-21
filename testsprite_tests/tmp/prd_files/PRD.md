# Sudan Free - Product Requirements Document (PRD)

## 1. Product Overview

**Sudan Free** is a freelance marketplace mobile application built with Flutter, connecting Sudanese freelancers with clients. The app enables users to post jobs, browse freelancer profiles, manage shops/products, communicate via chat, and handle payments — all in Arabic (RTL).

**Tech Stack:** Flutter/Dart, Firebase (Auth, Firestore, Storage, Messaging), Cloudinary (media), Provider (state management)

**Version:** 1.6.0+6

---

## 2. Core Features

### 2.1 Authentication & User Management
- **Google Sign-In** and **Email/Password** authentication via Firebase Auth
- **Profile Setup Screen** — new users fill in personal information after registration
- **User Model** — stores name, email, photo, bio, skills, location (Sudan cities/states), rating, account type (freelancer/client/shop), rank system
- **Onboarding** — first-time user walkthrough

### 2.2 Jobs & Proposals
- **Post Jobs** — clients create job listings with title, description, budget, category, location, deadline
- **Browse Jobs** — freelancers search and filter available jobs
- **Submit Proposals** — freelancers apply to jobs with cover letter, proposed budget, and timeline
- **Manage Proposals** — clients review, accept, or reject proposals

### 2.3 Social Posts Feed
- **Create Posts** — users share text posts with optional images/videos
- **Post Details** — view full post with comments and reactions
- **Reactions** — like/react to posts
- **Comments System** — threaded comments with replies, colored reply indicators
- **Share Posts** — share content externally

### 2.4 Freelancer Profiles
- **Browse Freelancers** — search and filter by skill, location, rating
- **Profile Screen** — displays portfolio, reviews, skills, and contact info
- **Reviews & Ratings** — clients leave reviews for freelancers after completed work
- **Rank System** — users earn ranks based on activity and reviews

### 2.5 Shops & Products
- **Create Shop Profile** — users can set up a shop
- **Browse Shops** — discover shops and their products
- **Add Products** — shop owners list products with images, price, description
- **Shop Profile Screen** — displays products and reviews

### 2.6 Chat & Messaging
- **Chat List** — view all conversations
- **Real-time Messaging** — send text messages between users
- **Message Model** — supports text, timestamps, read status

### 2.7 Payments
- **Payment Model** — track payment transactions between clients and freelancers
- **Payment Provider** — manages payment state and operations

### 2.8 Notifications
- **Push Notifications** — Firebase Cloud Messaging for likes, comments, mentions, reviews
- **Local Notifications** — in-app notification display
- **Notification Screen** — view all notification history
- **Background Message Handling** — processes notifications when app is closed

### 2.9 Settings & Privacy
- **Settings Screen** — edit profile info via modal bottom sheet
- **Privacy Policy** — in-app privacy policy display
- **Report System** — report inappropriate content or users
- **Safety Screen** — safety guidelines and resources

### 2.10 Search & Discovery
- **Smart Search** — intelligent search across jobs, freelancers, shops, posts
- **Location-based Filtering** — filter by Sudan states and cities

---

## 3. Technical Features

### 3.1 Data Layer
- **Firestore Service** — CRUD operations for all collections (users, jobs, posts, proposals, reviews, payments, messages, notifications, reports)
- **Cache Service** — local caching with Hive for offline access
- **Firestore Security Rules** — role-based access control preventing unauthorized data modifications
- **Offline Persistence** — Firestore offline support enabled

### 3.2 Media Handling
- **Image Picker** — capture or select images from gallery
- **Image Compression** — compress images before upload
- **Cloudinary Upload** — store media on Cloudinary CDN
- **Cached Network Images** — efficient image loading with caching
- **Video Player** — play video content in posts
- **Photo View** — zoomable full-screen image viewer

### 3.3 State Management
- **Provider Pattern** — AuthProvider, JobProvider, PaymentProvider, LocationProvider, LocaleProvider
- **Error Handling** — global error service with logging

### 3.4 Localization
- **Arabic (ar)** — primary language, RTL layout
- **Internationalization** — using Flutter intl package

### 3.5 Cloud Functions
- **Notification Functions** — Firebase Cloud Functions send push notifications for social interactions

---

## 4. API Endpoints (Firestore Collections)

| Collection | Description |
|---|---|
| `users` | User profiles and settings |
| `jobs` | Job listings |
| `proposals` | Job applications from freelancers |
| `posts` | Social feed posts |
| `comments` | Comments on posts |
| `reviews` | User reviews and ratings |
| `payments` | Payment transactions |
| `messages` | Chat messages |
| `notifications` | User notifications |
| `reports` | Content/user reports |

---

## 5. User Flows

### 5.1 Registration Flow
1. User opens app → Onboarding screens
2. Sign up with Google or Email/Password
3. Fill profile setup form (name, location, skills, account type)
4. Navigate to home screen

### 5.2 Job Posting Flow
1. Client creates new job → fills details
2. Job appears in browse list
3. Freelancers view job and submit proposals
4. Client reviews proposals → accepts one
5. Work is completed → client leaves review

### 5.3 Social Feed Flow
1. User creates post with text/media
2. Other users see post in feed
3. Users react, comment, or share
4. Post author receives notifications

### 5.4 Shop Flow
1. User creates shop profile
2. Adds products with images and prices
3. Other users browse and view products
4. Buyers contact shop owner via chat
