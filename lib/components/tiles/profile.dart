import 'package:flutter/material.dart';

import 'package:squadquest/models/user.dart';

class ProfileTile extends ListTile {
  final UserProfile profile;

  ProfileTile(
      {super.key,
      super.onTap,
      super.subtitle,
      super.trailing,
      required this.profile})
      : super(
          leading: profile.photo != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(profile.photo.toString()),
                )
              : const CircleAvatar(
                  child: Icon(Icons.person),
                ),
          title: Text(profile.displayName),
        );
}
