import 'package:flutter/material.dart';

import '../../core/app_identity.dart';
import '../theme/dept_accounting_tokens.dart';
import 'dept_accounting_controls.dart';

typedef DeptAccountingDestination = ({String label, IconData icon});

class DeptAccountingWorkspace extends StatelessWidget {
  const DeptAccountingWorkspace({
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
    this.compactDestinations = const [],
    this.compactSelectedIndex = 0,
    this.onCompactSelected,
    this.compactFocused = false,
  });
  final List<DeptAccountingDestination> destinations;
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
  final List<DeptAccountingDestination> compactDestinations;
  final int compactSelectedIndex;
  final ValueChanged<int>? onCompactSelected;
  final bool compactFocused;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final expanded = size.maxWidth >= DeptAccountingLayout.expanded;
      final compact =
          size.maxWidth < DeptAccountingLayout.compact && !libraryMode;
      final scrollNotice =
          size.maxWidth < DeptAccountingLayout.compact && notice != null;
      final body = scrollBody
          ? DeptAccountingPageBody(key: ValueKey(selectedIndex), child: child)
          : child;
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
        bottomNavigationBar:
            compact && !compactFocused && compactDestinations.isNotEmpty
            ? NavigationBar(
                selectedIndex: compactSelectedIndex,
                onDestinationSelected: onCompactSelected,
                height: 72,
                backgroundColor: DeptAccountingColors.surface,
                indicatorColor: DeptAccountingColors.primarySoft,
                labelTextStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 11),
                ),
                destinations: [
                  for (final item in compactDestinations)
                    NavigationDestination(
                      icon: Icon(item.icon, size: 22),
                      label: item.label,
                    ),
                ],
              )
            : null,
        drawer: expanded
            ? null
            : Drawer(
                width: DeptAccountingLayout.sidebar + 24,
                child: SafeArea(child: sidebar),
              ),
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expanded)
                SizedBox(width: DeptAccountingLayout.sidebar, child: sidebar),
              Expanded(
                child: Column(
                  children: [
                    if (!compact || !compactFocused)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: DeptAccountingColors.border,
                            ),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: size.maxWidth < 600 ? 16 : 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            if (!expanded && !compact)
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
                                compact ? appName : '$appName  /  $title',
                                style: const TextStyle(
                                  color: DeptAccountingColors.muted,
                                ),
                              ),
                            ),
                            if (compact && onProfilePressed != null)
                              IconButton(
                                tooltip: 'الملف الشخصي',
                                onPressed: onProfilePressed,
                                icon: const Icon(Icons.person_outline),
                              ),
                          ],
                        ),
                      ),
                    if (!scrollNotice) ?notice,
                    Expanded(
                      child: scrollNotice
                          ? _ScrollingWorkspaceNotice(
                              notice: notice!,
                              child: body,
                            )
                          : body,
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

class _ScrollingWorkspaceNotice extends InheritedWidget {
  const _ScrollingWorkspaceNotice({required this.notice, required super.child});

  final Widget notice;

  @override
  bool updateShouldNotify(_ScrollingWorkspaceNotice oldWidget) =>
      notice != oldWidget.notice;
}

class DeptAccountingPageBody extends StatelessWidget {
  const DeptAccountingPageBody({super.key, required this.child});
  final Widget child;
  static Widget? noticeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ScrollingWorkspaceNotice>()
      ?.notice;
  @override
  Widget build(BuildContext context) {
    final notice = context
        .dependOnInheritedWidgetOfExactType<_ScrollingWorkspaceNotice>()
        ?.notice;
    return LayoutBuilder(
      builder: (context, size) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?notice,
            Padding(
              padding: EdgeInsets.all(
                size.maxWidth < DeptAccountingLayout.compact ? 16 : 24,
              ),
              child: Align(
                alignment: AlignmentDirectional.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: DeptAccountingLayout.maxContent,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final List<DeptAccountingDestination> destinations;
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
    shape: const BorderDirectional(
      end: BorderSide(color: DeptAccountingColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact
              ? const EdgeInsets.fromLTRB(24, 32, 24, 28)
              : const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DeptAccountingColors.primary,
                  borderRadius: BorderRadius.all(
                    Radius.circular(DeptAccountingLayout.brandRadius),
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
                        fontSize:
                            MediaQuery.sizeOf(context).width <
                                DeptAccountingLayout.compact
                            ? 25
                            : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      libraryMode
                          ? 'لغة واحدة لكل واجهات المحل'
                          : 'إدارة محلك، بكل بساطة',
                      style: const TextStyle(
                        color: DeptAccountingColors.muted,
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
            style: const TextStyle(
              color: DeptAccountingColors.muted,
              fontSize: 12,
            ),
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
                    selectedTileColor: DeptAccountingColors.primarySoft,
                    selectedColor: DeptAccountingColors.primary,
                    iconColor: DeptAccountingColors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DeptAccountingLayout.smallRadius,
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
          padding: const EdgeInsets.all(DeptAccountingSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: DeptAccountingSpace.sm,
                ),
                child: Divider(),
              ),
              const SizedBox(height: DeptAccountingSpace.sm),
              if (onProfilePressed != null)
                Tooltip(
                  message: 'الملف الشخصي',
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DeptAccountingSpace.sm,
                      vertical: DeptAccountingSpace.xs,
                    ),
                    minLeadingWidth: 36,
                    horizontalTitleGap: DeptAccountingSpace.md,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        DeptAccountingLayout.smallRadius,
                      ),
                    ),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: DeptAccountingColors.primarySoft,
                      child: Text(
                        profileName?.isNotEmpty == true
                            ? profileName!.characters.first
                            : 'د',
                        style: const TextStyle(
                          color: DeptAccountingColors.primary,
                        ),
                      ),
                    ),
                    title: Text(
                      profileName ?? 'الملف الشخصي',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DeptAccountingTypography.control,
                    ),
                    subtitle: profileRole == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: DeptAccountingSpace.xs,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: DeptAccountingStatusTag(
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
                  padding: const EdgeInsets.all(DeptAccountingSpace.sm),
                  child: Text(footer, style: DeptAccountingTypography.caption),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: DeptAccountingSpace.sm,
                  top: DeptAccountingSpace.sm,
                ),
                child: Text(
                  'الإصدار 1.0',
                  style: DeptAccountingTypography.caption.copyWith(
                    fontSize: 10,
                    color: DeptAccountingColors.muted,
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
