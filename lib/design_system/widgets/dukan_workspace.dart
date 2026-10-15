import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../theme/dukan_tokens.dart';
import 'dukan_controls.dart';

typedef DukanDestination = ({String label, IconData icon});

class DukanWorkspace extends StatelessWidget {
  const DukanWorkspace({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.child,
    this.title = 'نظام التصميم',
    this.footer = '$appName · مكتبة الواجهات',
    this.scrollBody = true,
    this.notice,
    this.libraryMode = true,
    this.profileName,
    this.profileRole,
    this.onProfilePressed,
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
  final String? profileName;
  final String? profileRole;
  final VoidCallback? onProfilePressed;

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
        profileName: profileName,
        profileRole: profileRole,
        onProfilePressed: onProfilePressed == null
            ? null
            : () {
                if (!expanded) Navigator.of(context).pop();
                onProfilePressed!();
              },
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
                              '$appName  /  $title',
                              style: const TextStyle(color: DukanColors.muted),
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
    required this.profileName,
    required this.profileRole,
    required this.onProfilePressed,
  });
  final List<DukanDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String footer;
  final bool libraryMode;
  final String? profileName;
  final String? profileRole;
  final VoidCallback? onProfilePressed;

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
                      appName,
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
          padding: const EdgeInsets.all(DukanSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: DukanSpace.sm),
                child: Divider(),
              ),
              const SizedBox(height: DukanSpace.sm),
              if (onProfilePressed != null)
                Tooltip(
                  message: 'الملف الشخصي',
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DukanSpace.sm,
                      vertical: DukanSpace.xs,
                    ),
                    minLeadingWidth: 36,
                    horizontalTitleGap: DukanSpace.md,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DukanLayout.smallRadius,
                      ),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: DukanColors.primarySoft,
                      child: Text(
                        profileName?.isNotEmpty == true
                            ? profileName!.characters.first
                            : 'د',
                        style: const TextStyle(color: DukanColors.primary),
                      ),
                    ),
                    title: Text(
                      profileName ?? 'الملف الشخصي',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DukanTypography.control,
                    ),
                    subtitle: profileRole == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(top: DukanSpace.xs),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: DukanStatusTag(
                                profileRole!,
                                compact: true,
                              ),
                            ),
                          ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: onProfilePressed,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(DukanSpace.sm),
                  child: Text(footer, style: DukanTypography.caption),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: DukanSpace.sm,
                  top: DukanSpace.sm,
                ),
                child: Text(
                  'الإصدار 1.0',
                  style: DukanTypography.caption.copyWith(
                    fontSize: 10,
                    color: DukanColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
