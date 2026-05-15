import 'package:flutter/material.dart';

class EchoAiAdvisor {
  final String id;
  final String name;
  final String role;
  final String description;
  final String status;
  final IconData icon;
  final List<Color> colors;
  final List<String> prompts;

  const EchoAiAdvisor({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.status,
    required this.icon,
    required this.colors,
    required this.prompts,
  });
}

const echoAiAdvisors = <EchoAiAdvisor>[
  EchoAiAdvisor(
    id: 'friend',
    name: 'Echo AI',
    role: 'Act like a friend',
    description:
        'Talk through your day, ideas, confusion, or anything you do not want to hold alone.',
    status: 'Always ready to listen',
    icon: Icons.favorite_rounded,
    colors: [Color(0xFFEF4E7B), Color(0xFFFFB86C)],
    prompts: [
      'I need someone to talk to',
      'Help me think clearly',
      'Give me honest advice',
    ],
  ),
  EchoAiAdvisor(
    id: 'health',
    name: 'Echo AI Health',
    role: 'Personal health advisor',
    description:
        'Simple wellness guidance, symptom questions, habits, and doctor-visit preparation.',
    status: 'Wellness support',
    icon: Icons.health_and_safety_rounded,
    colors: [Color(0xFF00A86B), Color(0xFF7CE7AC)],
    prompts: [
      'Help me understand symptoms',
      'Build a healthy routine',
      'Prepare questions for a doctor',
    ],
  ),
  EchoAiAdvisor(
    id: 'fitness',
    name: 'Echo AI Fitness',
    role: 'Fitness advisor',
    description:
        'Workout plans, home exercises, recovery tips, and habit tracking ideas.',
    status: 'Training mode',
    icon: Icons.fitness_center_rounded,
    colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
    prompts: [
      'Make a home workout',
      'Plan weight loss exercise',
      'Improve my stamina',
    ],
  ),
  EchoAiAdvisor(
    id: 'finance',
    name: 'Echo AI Finance',
    role: 'Finance advisor',
    description:
        'Budget planning, saving goals, expense review, and money decisions in plain language.',
    status: 'Money planning',
    icon: Icons.account_balance_wallet_rounded,
    colors: [Color(0xFF7C3AED), Color(0xFF38BDF8)],
    prompts: [
      'Create a monthly budget',
      'Help reduce expenses',
      'Plan a saving goal',
    ],
  ),
  EchoAiAdvisor(
    id: 'travel',
    name: 'Echo AI Travel',
    role: 'Travel advisor',
    description:
        'Trip ideas, packing lists, route planning, local tips, and travel budgets.',
    status: 'Trip builder',
    icon: Icons.flight_takeoff_rounded,
    colors: [Color(0xFFFF7A18), Color(0xFFFFD166)],
    prompts: [
      'Plan a weekend trip',
      'Make a packing list',
      'Find budget travel ideas',
    ],
  ),
  EchoAiAdvisor(
    id: 'study',
    name: 'Echo AI Study',
    role: 'Study advisor',
    description:
        'Study plans, summaries, exam prep, notes, and daily learning discipline.',
    status: 'Focus partner',
    icon: Icons.school_rounded,
    colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
    prompts: [
      'Make a study timetable',
      'Explain this topic simply',
      'Quiz me for exams',
    ],
  ),
  EchoAiAdvisor(
    id: 'career',
    name: 'Echo AI Career',
    role: 'Career advisor',
    description:
        'Resume review, interview practice, skill plans, and work communication help.',
    status: 'Career coach',
    icon: Icons.work_rounded,
    colors: [Color(0xFF334155), Color(0xFF14B8A6)],
    prompts: [
      'Improve my resume',
      'Practice interview answers',
      'Plan my next skill',
    ],
  ),
  EchoAiAdvisor(
    id: 'food',
    name: 'Echo AI Food',
    role: 'Food advisor',
    description:
        'Meal ideas, grocery lists, diet-friendly recipes, and quick cooking help.',
    status: 'Meal planner',
    icon: Icons.restaurant_rounded,
    colors: [Color(0xFFDC2626), Color(0xFFF97316)],
    prompts: [
      'Suggest dinner today',
      'Make a grocery list',
      'Plan protein meals',
    ],
  ),
  EchoAiAdvisor(
    id: 'mind',
    name: 'Echo AI Mind',
    role: 'Mindfulness advisor',
    description:
        'Stress reset, journaling prompts, breathing routines, and calm thinking support.',
    status: 'Calm space',
    icon: Icons.self_improvement_rounded,
    colors: [Color(0xFF06B6D4), Color(0xFFA78BFA)],
    prompts: [
      'Help me calm down',
      'Give me journal prompts',
      'Guide a breathing reset',
    ],
  ),
  EchoAiAdvisor(
    id: 'tech',
    name: 'Echo AI Tech',
    role: 'Tech advisor',
    description:
        'Code help, app ideas, debugging steps, tools, and learning technical concepts.',
    status: 'Problem solver',
    icon: Icons.terminal_rounded,
    colors: [Color(0xFF111827), Color(0xFF3B82F6)],
    prompts: [
      'Explain this error',
      'Help design an app feature',
      'Teach me a tech concept',
    ],
  ),
];
