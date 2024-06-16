import {
  getAnonSupabaseClient,
  getServiceRoleSupabaseClient,
  getSupabaseUser,
} from "../_shared/supabase.ts";

import { JWT } from "npm:google-auth-library@9";
import serviceAccount from "../firebase-service-account.json" with {
  type: "json",
};

interface Notification {
  title: string;
  body: string;
  image?: string;
}

interface Message {
  token?: string;
  name?: string;
  notification?: Notification;
  data?: { [key: string]: string };
  android?: { collapseKey?: string; notification?: { icon: string } };
  apns?: { headers: { "apns-collapse-id": string } };
}

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

async function postMessage(
  message: Message,
): Promise<Message> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${await getAccessToken()}`,
      },
      body: JSON.stringify({
        message,
      }),
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

export type { Notification };

export { getAccessToken, postMessage };
