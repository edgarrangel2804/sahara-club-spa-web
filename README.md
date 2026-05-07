# Sahara Club Spa Web

A luxury wellness digital platform built with Flutter for the web.

## Features

### Main Website
- **Landing Page**: Elegant spa website with hero section, services, experience, and contact information
- **Responsive Design**: Optimized for desktop and mobile viewing
- **Luxury Aesthetics**: Dark theme with gold accents and smooth animations

### Digital Wellness Platform
A premium digital experience featuring:

#### Core Sections
- **Tonight's Ritual**: Featured immersive wellness experience with cinematic presentation
- **Meditations for the Soul**: Horizontal scrolling cards of guided meditation sessions
- **Deep Relaxation Sounds**: Luxury audio player interface for ambient sounds
- **Exclusive Sahara Sessions**: VIP-locked premium content with membership access
- **Wellness Courses**: Cinematic course thumbnails with progress tracking
- **Your Healing Journey**: Personalized recommendations based on user preferences
- **Continue Your Ritual**: Resume previously started sessions- **Sahara Boutique**: Luxury wellness shop with premium products and memberships
#### Design Philosophy
- **Cinematic Experience**: Slow fade transitions, floating smoke effects, soft glowing highlights
- **Luxury Aesthetics**: Deep black and burgundy gradients, warm gold accents
- **Emotional Design**: Calming, immersive, and addictive user experience
- **Exclusive Feel**: Private members-only club atmosphere

#### Technical Features
- **Smooth Animations**: Custom fade-in effects and floating atmospheric elements
- **Responsive Layout**: Adaptive design for various screen sizes
- **Custom Typography**: Elegant serif titles with clean modern sans-serif subtitles
- **Glassmorphism Elements**: Subtle transparency effects for premium feel

## Getting Started

### Prerequisites
- Flutter SDK (3.0 or higher)
- Dart SDK
- Web browser for testing

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd sahara-club-spa-web
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the development server:
```bash
flutter run -d web
```

4. Build for production:
```bash
flutter build web --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── theme/
│   └── sahara_theme.dart     # Custom theme with luxury colors
├── pages/
│   ├── landing_page.dart     # Main website landing page
│   └── wellness_platform_page.dart  # Digital wellness platform
├── widgets/
│   ├── navbar.dart           # Navigation bar with wellness button
│   ├── wellness_sections.dart # All wellness platform UI sections
│   ├── floating_smoke.dart   # Atmospheric animation effects
│   └── ...                   # Other UI components
└── assets/
    ├── fonts/                # Custom typography
    └── images/               # Visual assets
```

## Design System

### Colors
- **Primary Black**: `#0B0B0B` - Deep, luxurious base
- **Burgundy**: `#4A0E0E` - Rich accent for gradients
- **Gold**: `#C6A76A` - Premium accent color
- **Beige**: `#E8DCC8` - Soft text color

### Typography
- **Titles**: Playfair Display (serif) - Elegant and sophisticated
- **Body Text**: Inter (sans-serif) - Clean and modern

### Animations
- Slow fade transitions (2-second duration)
- Floating smoke effects with opacity and scale animations
- Smooth scrolling with cubic easing
- Cinematic entrance effects

## Contributing

1. Follow the established design system
2. Maintain the luxury aesthetic in all new components
3. Ensure responsive design across devices
4. Test animations and transitions thoroughly

## License

This project is proprietary to Sahara Club Spa.
