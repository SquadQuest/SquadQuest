import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "../firebase-service-account.json" with {
  type: "json",
};

function getAccessToken(): Promise<string> {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    jwtClient.authorize((err, data) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(data!.access_token!);
    });
  });
}

interface Message {
  token?: string;
  title: string;
  body: string;

  url?: string;
  payload?: object;
  collapseKey?: string;
  icon?: string;
}

async function postMessage(
  {
    token,
    title,
    body,
    icon = "https://squadquest.app/icons/Icon-192.png",
    ...options
  }: Message,
): Promise<Message> {
  // deno-lint-ignore no-explicit-any
  const message: any = {
    token,
    notification: {
      title,
      body,
    },
    data: {},
    android: {},
    apns: { headers: {} },
    webpush: { notification: {} },
  };

  if (options.url) {
    message.data.url = options.url;
  }

  if (options.payload) {
    message.data.json = JSON.stringify(options.payload);
  }

  if (options.collapseKey) {
    message.android.collapseKey = options.collapseKey;
    message.apns.headers["apns-collapse-id"] = options.collapseKey;
    message.webpush.notification.tag = options.collapseKey;
  }

  if (icon) {
    message.webpush.notification.icon = icon;
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${await getAccessToken()}`,
      },
      body: JSON.stringify({ message }),
    },
  );

  const responseData = await response.json();
  if (response.status < 200 || 299 < response.status) {
    const message = responseData?.error?.message ??
      `status=${response.status}, response=${JSON.stringify(responseData)}`;
    throw `Failed to send push notification: ${message}`;
  }

  return responseData;
}

// export type { Notification };

export { getAccessToken, postMessage };
