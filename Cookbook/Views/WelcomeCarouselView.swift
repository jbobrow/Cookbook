//
//  WelcomeCarouselView.swift
//  Cookbook
//
//  Welcome carousel shown on first launch
//

import SwiftUI

struct WelcomeCarouselView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var currentPage = 0

    let pages: [WelcomePage] = [
        WelcomePage(
            icon: "book.fill",
            title: "Welcome to Cookbook",
            description: "Your personal recipe collection, beautifully organized and always at your fingertips.",
            color: .blue
        ),
        WelcomePage(
            icon: "list.bullet.rectangle.fill",
            title: "Organize Your Recipes",
            description: "Create multiple cookbooks and use color-coded categories to keep everything perfectly organized.",
            color: .green
        ),
        WelcomePage(
            icon: "checkmark.circle.fill",
            title: "Cook with Confidence",
            description: "Check off ingredients as you prep and mark directions as complete while you cook. Keep track of your favorite recipes you've already made.",
            color: .orange
        ),
        WelcomePage(
            icon: "icloud.fill",
            title: "Sync Everywhere",
            description: "Use iCloud to keep your recipes synced across all your devices, or store them locally—it's your choice.",
            color: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    WelcomePageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Bottom button
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button(action: {
                        withAnimation {
                            hasSeenWelcome = true
                        }
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(pages[currentPage].color)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 24) {
                        Button(action: {
                            hasSeenWelcome = true
                        }) {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(pages[currentPage].color)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity)
                }
            }
            .frame(height: 80)
            .padding(.bottom, 20)
        }
    }
}

struct WelcomePageView: View {
    let page: WelcomePage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .symbolEffect(.bounce, value: page.icon)

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct WelcomePage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

#Preview {
    WelcomeCarouselView()
}
