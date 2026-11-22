//
//  TabbarController.swift
//  feather
//
//  Created by samara on 5/17/24.
//  Copyright (c) 2024 Samara M (khcrysalis)
//

import SwiftUI
import NukeUI
private enum ExtendedTabSelection: Hashable { case tab(TabEnum); case search; case allRepositories; case source(URL) }

@available(iOS 18, *)
struct ExtendedTabbarView: View {
	@Environment(\.horizontalSizeClass) var horizontalSizeClass
	@AppStorage("XSign.tabCustomization") var customization = TabViewCustomization()
	@StateObject var viewModel = SourcesViewModel.shared
	
	@State private var _isAddingPresenting = false
	@State private var _selectedTab: ExtendedTabSelection = .tab(.sources)
	@State private var _lastNonSearchTab: TabEnum = .sources
	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>
		
	var body: some View {
		TabView(selection: $_selectedTab) {
			ForEach(TabEnum.defaultTabs, id: \.hashValue) { tab in
				Tab(tab.title, systemImage: tab.icon, value: ExtendedTabSelection.tab(tab)) { 
					TabEnum.view(for: tab)
				}
			}
			
			Tab("Tìm kiếm", systemImage: "magnifyingglass", value: ExtendedTabSelection.search, role: .search) {
				NavigationStack {
					GlobalSearchView(onExitSearch: { _selectedTab = .tab(_lastNonSearchTab) })
				}
			}
			
			ForEach(TabEnum.customizableTabs, id: \.hashValue) { tab in
				Tab(tab.title, systemImage: tab.icon, value: ExtendedTabSelection.tab(tab)) {
					TabEnum.view(for: tab)
				}
				.customizationID("tab.\(tab.rawValue)")
				.defaultVisibility(.hidden, for: .tabBar)
				.customizationBehavior(.reorderable, for: .tabBar, .sidebar)
				.hidden(horizontalSizeClass == .compact)
			}
			
			TabSection("Sources") {
				Tab(.localized("All Repositories"), systemImage: "globe", value: ExtendedTabSelection.allRepositories) {
					NavigationStack {
						SourceAppsView(object: Array(_sources), viewModel: viewModel)
					}
				}
				
				ForEach(_sources, id: \.identifier) { source in
					Tab(value: ExtendedTabSelection.source(source.objectID.uriRepresentation())) {
						NavigationStack {
							SourceAppsView(object: [source], viewModel: viewModel)
						}
					} label: {
						_icon(source.name ?? .localized("Unknown"), iconUrl: source.iconURL)
					}
					.swipeActions {
						Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
							Storage.shared.deleteSource(for: source)
						}
					}
				}
			}
			.sectionActions {
				Button(.localized("Add Source"), systemImage: "plus") {
					_isAddingPresenting = true
				}
			}
			.defaultVisibility(.hidden, for: .tabBar)
			.hidden(horizontalSizeClass == .compact)
		}
		.tabViewStyle(.sidebarAdaptable)
		.tabViewCustomization($customization)
		.sheet(isPresented: $_isAddingPresenting) {
			SourcesAddView()
				.presentationDetents([.medium])
		} .onChange(of: _selectedTab) { _, newValue in if case .tab(let t) = newValue { _lastNonSearchTab = t } }
	}
	
	@ViewBuilder
	private func _icon(_ title: String, iconUrl: URL?) -> some View {
		Label {
			Text(title)
		} icon: {
			if let iconURL = iconUrl {
				LazyImage(url: iconURL) { state in
					if let image = state.image {
						image
					} else {
						standardIcon
					}
				}
				.processors([.resize(width: 14), .circle()])
			} else {
				standardIcon
			}
		}
	}

	
	var standardIcon: some View {
		Image(systemName: "app.dashed")
	}
}

