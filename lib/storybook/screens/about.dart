import 'package:flutter/material.dart';
import 'package:lit_starfield/view/lit_starfield_container.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Bottom layer: Starfield
          const LitStarfieldContainer(
            animated: true,
            number: 100,
            velocity: 0.85,
            depth: 0.9,
            scale: 4,
            starColor: Colors.white,
          ),

          // Middle layer: Ganja cutout image
          Center(
            child: Image.network(
              'https://storage.googleapis.com/storybook.squadquest.app/images/ganja-cutout.png?v2',
              fit: BoxFit.contain,
              color: Colors.white.withAlpha(150),
              colorBlendMode: BlendMode.modulate,
            ),
          ),

          // Top layer: About text
          const Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Text(
              'Welcome to SquadQuest\n\n'
              'Your journey to find your perfect squad begins here. '
              'Connect with like-minded individuals, join communities, '
              'and embark on amazing adventures together.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
