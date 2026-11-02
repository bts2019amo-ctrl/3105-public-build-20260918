import SwiftUI

struct RepositoryHomeView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: PackageRepositoryStore
    @State private var feed: [RepositoryPackageRecord] = []

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if feed.isEmpty {
                        emptyContent
                    } else {
                        featuredFeed
                        recentPackages
                    }

                }
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.contentCardInset)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .refreshable {
                await store.refreshAllAndWait()
                rebuildFeed()
            }
            .navigationTitle("3105")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .navigationDestination(for: RepositoryPackageRecord.self) { record in
                RepositoryPackageDetailView(record: record)
            }
            .onAppear {
                store.refreshAllIfNeeded()
                if feed.isEmpty {
                    rebuildFeed()
                }
            }
            .onChange(of: store.packages) { _ in
                rebuildFeed()
            }
        }
    }

    private var emptyContent: some View {
        marketplaceEmpty(
            systemImage: store.sources.isEmpty
                ? "shippingbox.and.arrow.backward"
                : "shippingbox",
            titleKey: store.sources.isEmpty
                ? "repository.no_sources_title"
                : "repository.no_packages_title",
            messageKey: store.sources.isEmpty
                ? "repository.home_no_sources_message"
                : "repository.no_packages_message"
        )
    }

    private var featuredFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("repository.for_you")

            GeometryReader { proxy in
                let cardWidth = featuredCardWidth(availableWidth: proxy.size.width)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: featuredCardSpacing) {
                        ForEach(Array(feed.prefix(featuredPackageCount))) { record in
                            NavigationLink(value: record) {
                                RepositoryFeaturedCard(
                                    record: record,
                                    width: cardWidth,
                                    height: featuredCardHeight
                                )
                            }
                            .buttonStyle(RepositoryCardButtonStyle())
                        }
                    }
                }
            }
            .frame(height: featuredCardHeight)
        }
    }

    @ViewBuilder
    private var recentPackages: some View {
        let remaining = Array(feed.dropFirst(featuredPackageCount))
        if !remaining.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("repository.more_patches")

                VStack(spacing: 0) {
                    ForEach(
                        Array(remaining.enumerated()),
                        id: \.element.id
                    ) { index, record in
                        NavigationLink(value: record) {
                            HStack(spacing: 12) {
                                RepositoryPackageRow(record: record)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, AppTheme.contentCardPadding)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(RepositoryCardButtonStyle())

                        if index < remaining.count - 1 {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(
                    Color(uiColor: .systemBackground),
                    in: RoundedRectangle(
                        cornerRadius: AppTheme.contentCardCornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    AppCardBorder()
                }
            }
        }
    }

    private func sectionHeader(_ key: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.accent)
                .frame(width: 4, height: 18)
            Text(language.text(key))
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    private func marketplaceEmpty(
        systemImage: String,
        titleKey: String,
        messageKey: String
    ) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }
            Text(language.text(titleKey))
                .font(.headline.weight(.semibold))
            Text(language.text(messageKey))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 52)
        .background(
            Color(uiColor: .systemBackground),
            in: RoundedRectangle(
                cornerRadius: AppTheme.contentCardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            AppCardBorder()
        }
    }

    private func rebuildFeed() {
        feed = PackageRepositoryFeedPolicy.home(store.packages)
    }

    private var featuredPackageCount: Int {
        min(feed.count, 3)
    }

    private var featuredCardSpacing: CGFloat { 10 }

    private var featuredCardHeight: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 200
        }
        if dynamicTypeSize >= .xxLarge {
            return 168
        }
        return 148
    }

    private func featuredCardWidth(availableWidth: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return min(320, max(260, availableWidth * 0.82))
        }
        if dynamicTypeSize >= .xxLarge {
            return min(
                260,
                max(200, (availableWidth - featuredCardSpacing) / 1.45)
            )
        }
        return min(
            240,
            max(140, (availableWidth - featuredCardSpacing) / 2)
        )
    }
}
