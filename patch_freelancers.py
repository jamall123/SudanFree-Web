with open('lib/views/freelancers/browse_freelancers_screen.dart', 'r') as f:
    content = f.read()

helper = """  Widget _buildAverageCostBanner(List<UserModel> filteredFreelancers, String locale) {
    if (_searchQuery.isEmpty) return const SizedBox.shrink();
    
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return const SizedBox.shrink();

    final withRates = filteredFreelancers.where((f) => f.hourlyRate != null && f.hourlyRate! > 0).toList();
    if (withRates.isEmpty) return const SizedBox.shrink();

    // 1. Try Locality
    var localRates = withRates.where((f) => f.locality == currentUser.locality).toList();
    String locationText = locale == 'ar' ? 'في منطقتك (${currentUser.locality ?? ''})' : 'in your locality (${currentUser.locality ?? ''})';

    // 2. Try State if Locality is empty
    if (localRates.isEmpty && currentUser.state != null) {
      localRates = withRates.where((f) => f.state == currentUser.state).toList();
      locationText = locale == 'ar' ? 'في ولايتك (${currentUser.state})' : 'in your state (${currentUser.state})';
    }

    // 3. Fallback to all
    if (localRates.isEmpty) {
      localRates = withRates;
      locationText = locale == 'ar' ? 'بشكل عام' : 'in general';
    }

    final average = localRates.map((f) => f.hourlyRate!).reduce((a, b) => a + b) / localRates.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locale == 'ar' 
                ? 'سيكلفك طلب هذه الخدمة بالتقريب ${average.toStringAsFixed(0)} SDG للساعة $locationText.'
                : 'Requesting this service will cost you approximately ${average.toStringAsFixed(0)} SDG/hr $locationText.',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override"""

content = content.replace("  @override\n  Widget build(BuildContext context) {", helper + "\n  Widget build(BuildContext context) {")

old_ui = """              ),
            ),
            
            // Expandable Filters"""

new_ui = """              ),
            ),
            
            _buildAverageCostBanner(freelancers, locale),
            
            // Expandable Filters"""

content = content.replace(old_ui, new_ui)

with open('lib/views/freelancers/browse_freelancers_screen.dart', 'w') as f:
    f.write(content)
