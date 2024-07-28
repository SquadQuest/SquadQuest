function scrubProfile(userProfile: { [key: string]: string | number }) {
  return {
    id: userProfile?.id,
    first_name: userProfile?.first_name,
    last_name: userProfile?.last_name,
    photo: userProfile?.photo,
  };
}

function normalizePhone(phone: string): string {
  return phone.replaceAll(/[^\d]/g, "");
}

export { normalizePhone, scrubProfile };
