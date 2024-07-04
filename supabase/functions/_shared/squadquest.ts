function scrubProfile(userProfile: { [key: string]: string | number }) {
  return {
    id: userProfile?.id,
    first_name: userProfile?.first_name,
  };
}

export { scrubProfile };
