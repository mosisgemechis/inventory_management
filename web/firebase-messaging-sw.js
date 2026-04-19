importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBLuXiaD-i1pQdDelNkeuFeAjYD9Yt4Oho",
  authDomain: "smart-inventory-c5d64.firebaseapp.com",
  projectId: "smart-inventory-c5d64",
  storageBucket: "smart-inventory-c5d64.firebasestorage.app",
  messagingSenderId: "948412189680",
  appId: "1:948412189680:web:35955fd1664a325582ab35",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message: ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png",
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
