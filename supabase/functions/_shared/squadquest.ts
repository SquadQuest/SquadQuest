import { getAnonSupabaseClient, getSupabaseUser } from "./supabase.ts";

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

export { normalizePhone, scrubProfile };
