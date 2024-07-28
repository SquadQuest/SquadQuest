import TwilioClient from "npm:twilio@5.2.2";

let twilioClient: TwilioClient.Twilio | null;
function getTwilioClient() {
  if (twilioClient) return twilioClient;

  return twilioClient = TwilioClient(
    Deno.env.get("TWILIO_ACCOUNT_SID"),
    Deno.env.get("TWILIO_AUTH_TOKEN"),
  );
}

async function sendSMS(phone: string, message: string): Promise<boolean> {
  const twilioClient = getTwilioClient();

  try {
    const response = await twilioClient.messages.create({
      body: message,
      to: phone,
      from: Deno.env.get("TWILIO_PHONE_NUMBER"),
    });

    return response.status == "queued";
  } catch (error) {
    console.error(`Failed to send SMS: ${error}`);
    return false;
  }
}

export { getTwilioClient, sendSMS };
