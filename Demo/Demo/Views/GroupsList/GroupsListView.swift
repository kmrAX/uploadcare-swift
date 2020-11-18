//
//  GroupsListView.swift
//  Demo
//
//  Created by Sergey Armodin on 24.06.2020.
//  Copyright © 2020 Sergei Armodin. All rights reserved.
//

import SwiftUI

struct GroupsListView: View {
	@ObservedObject var viewModel: GroupsListViewModel
	
    var body: some View {
		ZStack {
			List {
				Section {
					ForEach(self.viewModel.groups) { [self] group in
						GroupRowView(groupData: group)
						.onAppear {
							if group.group.id == viewModel.groups.last?.group.id {
								viewModel.loadMoreIfNeed()
							}
						}
					}
				}
			}
		}.onAppear { [self] in
			viewModel.loadData()
        }.navigationBarTitle(Text("List of groups"))
	}
}

struct GroupsListView_Previews: PreviewProvider {
    static var previews: some View {
		GroupsListView(viewModel: GroupsListViewModel())
    }
}
