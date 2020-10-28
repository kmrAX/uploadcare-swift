//
//  ContentView.swift
//  Demo
//
//  Created by Sergey Armodin on 26.03.2020.
//  Copyright © 2020 Sergei Armodin. All rights reserved.
//

import SwiftUI

struct MainView: View {
	@EnvironmentObject var api: APIStore
	@EnvironmentObject var uploader: Uploader
	
    var body: some View {
		NavigationView {
            ZStack {
                List {
                    NavigationLink(destination: FilesListView()) {
                        Text("List of files")
                    }
					NavigationLink(destination: GroupsListView()) {
                        Text("List of file groups")
                    }
					NavigationLink(destination: ProjectInfoView()) {
                        Text("Project info")
                    }
                }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text("Uploadcare demo"), displayMode: .automatic)
            }
		}
		
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
		MainView()
			.environmentObject(APIStore())
			.previewDevice(PreviewDevice(rawValue: "iPhone X"))
    }
}