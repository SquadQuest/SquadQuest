import { getAnonSupabaseClient, getSupabaseUser } from "./supabase.ts";

type UserID = string;
type TopicID = string;
type EventID = string;

enum EventVisibility {
  private = "private",
  friends = "friends",
  public = "public",
}

enum EventStatus {
  draft = "draft",
  live = "live",
  canceled = "canceled",
}

interface Geographic {
  lon: number;
  lat: number;
}

interface Event {
  id?: EventID;
  created_at?: Date;
  created_by?: UserID;
  updated_at?: Date;
  status?: EventStatus;
  start_time_min?: Date;
  start_time_max?: Date;
  end_time?: Date;
  topic?: TopicID;
  title?: string;
  visibility?: EventVisibility;
  location_description?: string;
  rally_point?: Geographic;
  rally_point_text?: string;
  link?: string;
  notes?: string;
  banner_photo?: string;
}

async function scrubProfile(
  userProfile: { [key: string]: string | number },
  isFriend: boolean | Request,
) {
  if (isFriend instanceof Request) {
    const currentUser = await getSupabaseUser(isFriend);
    const { count: existingFriendsCount } = await getAnonSupabaseClient(
      isFriend,
    ).from(
      "friends",
    )
      .select("*", { count: "exact", head: true })
      .in("requester", [currentUser!.id, userProfile.id])
      .in("requestee", [currentUser!.id, userProfile.id])
      .throwOnError();

    isFriend = existingFriendsCount! > 0;
  }

  if (isFriend) {
    return {
      id: userProfile?.id,
      first_name: userProfile?.first_name,
      last_name: userProfile?.last_name,
      phone: userProfile?.phone,
      photo: userProfile?.photo,
      trail_color: userProfile?.trail_color,
    };
  }

  return {
    id: userProfile?.id,
    first_name: userProfile?.first_name,
  };
}

function normalizePhone(phone: string): string {
  phone = phone.replaceAll(/[^\d]/g, "");

  // assume north american prefix
  if (phone.length == 10 && phone[0] != "1") {
    phone = `1${phone}`;
  }

  return phone;
}

// Export types
export type { Event, EventID, Geographic, TopicID, UserID };

// Export values
export { EventStatus, EventVisibility, normalizePhone, scrubProfile };
