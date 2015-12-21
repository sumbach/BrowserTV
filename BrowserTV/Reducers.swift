//
//  Reducers.swift
//  BrowserTV
//
//  Created by Sash Zats on 12/18/15.
//  Copyright © 2015 Sash Zats. All rights reserved.
//

import Foundation


struct BrowserReducer: Reducer {
    typealias ReducerStateType = AppState
    
    func handleAction(state: AppState, action: Action) -> AppState {
        guard let type = ActionKind(rawValue: action.type) else {
            assertionFailure("Unknown action \(action)")
            return state
        }

        switch type {
        case .Add:
            guard let payload = action.payload else {
                assertionFailure("No payload provided")
                return state
            }
            return addBrowserTab(state, payload: payload)
        case .Remove:
            guard let payload = action.payload else {
                assertionFailure("No payload provided")
                return state
            }
            return removeBrowserTab(state, payload: payload)
        case .SelectedTab:
            guard let payload = action.payload else {
                assertionFailure("No payload provided")
                return state
            }
            return selectTab(state, payload: payload)
        case .AdvanceTab:
            return advanceTab(state)
        case .ShowPreferences:
            return showPreferences(state)
        case .HidePreferences:
            return hidePreferenes(state)
        case .AcknowledgeTimerReset:
            return acknowledgeTimerReset(state)
        case .LoadState:
            return loadState(state)
        case .SaveState:
            return saveState(state)
        }
    }
}


// MARK: Tab management

extension BrowserReducer {
    private func addBrowserTab(var state: AppState, payload: [String: AnyObject]) -> AppState {
        guard let URL = payload["URL"] as? NSURL else {
            assertionFailure("Add tab requires URL")
            return state
        }
        let tab = BrowserTabState(URL: URL)
        state.browser.addTab(tab)
        state.preferences.URLs.append(URL.absoluteString)
        state.timer.shouldReset = true
        state.preferences.isVisible = true
        return state
    }
    
    private func removeBrowserTab(var state: AppState, payload: [String: AnyObject]) -> AppState {
        guard let index = payload["index"] as? Int else {
            assertionFailure("Removing tab requires index")
            return state
        }
        state.browser.removeTabAtIndex(index)
        state.preferences.URLs.removeAtIndex(index)
        state.timer.shouldReset = true
        return state
    }
}


// MARK: Tab Selection

extension BrowserReducer {
    private func selectTab(var state: AppState, payload: [String: AnyObject]) -> AppState {
        guard let index = payload["index"] as? Int else {
            assertionFailure("No index for tab selected")
            return state
        }
        print("Selecting tab \(index)")
        state.browser.selectedTabIndex = index
        state.timer.shouldReset = true
        print(state)
        return state
    }
    
    private func advanceTab(var state: AppState) -> AppState {
        guard let index = state.browser.selectedTabIndex else {
            return state
        }
        if index == state.browser.tabs.count - 1 {
            state.browser.selectedTabIndex = 0
        } else {
            state.browser.selectedTabIndex = index + 1
        }
        return state
    }
    
    private func acknowledgeTimerReset(var state: AppState) -> AppState {
        state.timer.shouldReset = false
        return state
    }
}

// MARK: Persistance

extension BrowserReducer {
    private var statePersistanceURL: NSURL {
        let manager = NSFileManager.defaultManager()
        let URL = try! manager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        return URL.URLByAppendingPathComponent("state.json")
    }
    
    func loadState(state: AppState) -> AppState {
        guard let data = NSData(contentsOfURL: statePersistanceURL),
            loadedState = AppState(data: data) else {
                return state
        }

        return loadedState
    }
    
    func saveState(state: AppState) -> AppState {
        if let data = state.data {
            do {
                try data.writeToURL(statePersistanceURL, options: [])
            } catch {
                assertionFailure("Failed to persist JSON")
            }
        } else {
            assertionFailure("JSON is invalid")
        }
        return state
    }
}

// MARK: Preferences

extension BrowserReducer {
    func showPreferences(var state: AppState) -> AppState {
        state.preferences.isVisible = true
        return state
    }
    
    func hidePreferenes(var state: AppState) -> AppState {
        state.preferences.isVisible = false
        return state
    }
}

private extension BrowserState {
    mutating func addTab(tab: BrowserTabState) {
        tabs.append(tab)
        if selectedTabIndex == nil {
           selectedTabIndex = 0
        }
    }
    
    mutating func removeTabAtIndex(index: Int) {
        tabs.removeAtIndex(index)
        if tabs.isEmpty {
            selectedTabIndex = nil
        } else {
            selectedTabIndex = tabs.count - 1
        }
    }
}

private extension AppState {
    init?(data: NSData) {
        guard let json = try? NSJSONSerialization.JSONObjectWithData(data, options: []) else {
            return nil
        }
        guard let interval = json["interval"] as? Double,
            URLStrings = json["URLs"] as? [String],
            URLs: [NSURL] = URLStrings.flatMap({ NSURL(string: $0) }) else {
                return nil
        }
        self.browser = BrowserState(
            switchInterval: interval,
            selectedTabIndex: URLs.isEmpty ? nil : 0,
            tabs: URLs.map{ BrowserTabState(URL: $0) })
        self.timer = TimerState(shouldReset: true)
        self.preferences = PreferencesState(
            isVisible: false,
            URLs: URLs.map{ $0.absoluteString }
        )
    }
    
    var data: NSData? {
        let json = [
            "interval": browser.switchInterval,
            "URLs": browser.tabs.map{ $0.URL.absoluteString }
        ]
        let data = try? NSJSONSerialization.dataWithJSONObject(json, options: [])
        return data
    }
}