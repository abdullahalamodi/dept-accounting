import 'package:flutter/material.dart';

import '../theme/dukan_tokens.dart';

typedef DukanDestination = ({String label, IconData icon});

class DukanWorkspace extends StatelessWidget {
  const DukanWorkspace({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    this.title = 'نظام التصميم',
    this.footer = 'دكّان · مكتبة الواجهات',
    this.scrollBody = true,
    this.notice,
    this.libraryMode = true,
  });
  final List<DukanDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget child;
  final String title;
  final String footer;
  final bool scrollBody;
  final Widget? notice;
  final bool libraryMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final expanded = size.maxWidth >= DukanLayout.expanded;
      final sidebar = _Sidebar(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onSelected: (index) {
          if (!expanded) Navigator.of(context).pop();
          onSelected(index);
        },
        footer: footer,
        libraryMode: libraryMode,
      );
      return Scaffold(
        drawer: expanded
            ? null
            : Drawer(
                width: DukanLayout.sidebar + 24,
                child: SafeArea(child: sidebar),
              ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expanded)
                SizedBox(width: DukanLayout.sidebar, child: sidebar),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: DukanColors.border),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: size.maxWidth < 600 ? 16 : 32,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          if (!expanded)
                            Builder(
                              builder: (context) => IconButton(
                                tooltip: 'فتح القائمة',
                                icon: const Icon(Icons.menu),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              'دكّان  /  $title',
                              style: const TextStyle(color: DukanColors.muted),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: DukanColors.primarySoft,
                            child: Text(
                              'د',
                              style: TextStyle(color: DukanColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ?notice,
                    Expanded(
                      child: scrollBody
                          ? DukanPageBody(
                              key: ValueKey(selectedIndex),
                              child: child,
                            )
                          : child,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class DukanPageBody extends StatelessWidget {
  const DukanPageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) => SingleChildScrollView(
      padding: EdgeInsets.all(size.maxWidth < 600 ? 16 : 32),
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: DukanLayout.maxContent),
          child: child,
        ),
      ),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.footer,
    required this.libraryMode,
  });
  final List<DukanDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String footer;
  final bool libraryMode;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const BorderDirectional(end: BorderSide(color: DukanColors.border)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DukanColors.primary,
                  borderRadius: BorderRadius.all(
                    Radius.circular(DukanLayout.brandRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'دكّان',
                      style: TextStyle(
                        fontFamily: 'NotoKufiArabic',
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      libraryMode
                          ? 'لغة واحدة لكل واجهات المحل'
                          : 'إدارة محلك، بكل بساطة',
                      style: const TextStyle(
                        color: DukanColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            libraryMode ? 'مكتبة التصميم' : 'مساحة العمل',
            style: const TextStyle(color: DukanColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (var i = 0; i < destinations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: selectedIndex == i,
                    selectedTileColor: DukanColors.primarySoft,
                    selectedColor: DukanColors.primary,
                    iconColor: DukanColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DukanLayout.smallRadius,
                      ),
                    ),
                    leading: Icon(destinations[i].icon, size: 21),
                    title: Text(
                      destinations[i].label,
                      style: const TextStyle(fontSize: 14),
                    ),
                    minLeadingWidth: 20,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 16),
              Text(
                footer,
                style: const TextStyle(fontSize: 12, color: DukanColors.muted),
              ),
              const SizedBox(height: 4),
              const Text(
                'الإصدار 1.0 · واجهة عربية',
                style: TextStyle(fontSize: 11, color: DukanColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
