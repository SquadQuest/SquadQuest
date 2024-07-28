function scrubProfile(userProfile: { [key: string]: string | number }) {
  return {
    id: userProfile?.id,
    first_name: userProfile?.first_name,
    last_name: userProfile?.last_name,
    photo: userProfile?.photo,
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
