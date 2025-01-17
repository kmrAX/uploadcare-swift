//
//  ProjectInfoViewModel.swift
//  Demo
//
//  Created by Sergey Armodin on 18.11.2020.
//  Copyright © 2020 Uploadcare, Inc. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Uploadcare

class ProjectInfoViewModel: ObservableObject {
	#if DEBUG
	static let testProject = Project(
		name: "Test project",
		pubKey: "demopublickey",
		collaborators: [
			Collaborator(email: "user1@gmail.com", name: "User 1"),
			Collaborator(email: "user2@gmail.com", name: "User 2")
		]
	)
	#endif
	
	// MARK: - Public properties
	var publicKey: String { projectData?.pubKey ?? "" }
	var collaborators: [CollaboratorViewData] {
		return projectData?.collaborators?.compactMap({ CollaboratorViewData(name: $0.name, email: $0.email) }) ?? []
	}
	var name: String { projectData?.name ?? "Loading" }
	
	// MARK: - Private properties
	private var uploadcare: Uploadcare?
	@Published private var projectData: Project?
	
	// MARK: - Init
	init(projectData: Project? = nil, uploadcare: Uploadcare? = nil) {
		self.projectData = projectData
		self.uploadcare = uploadcare
	}
}

extension ProjectInfoViewModel {
	func loadData(onComplete: @escaping ()->Void) {
		guard let api = uploadcare else {
			onComplete()
			return
		}

		api.getProjectInfo { result in
			switch result {
			case .failure(let error):
				DLog(error)
			case .success(let project):
				self.projectData = project
				onComplete()
			}
		}
	}
}
