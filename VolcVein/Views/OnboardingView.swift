import SwiftUI

/// Two pages: the hook, then the three rules. Skippable from either.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            if page == 0 { hookPage.transition(.opacity) } else { rulesPage.transition(.opacity) }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onFinish()
                    } label: {
                        Text("Skip")
                            .microLabel()
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(VV.ink.opacity(0.82))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(PressPlateStyle())
                }
                Spacer()
            }
            // The overlay already sits inside the safe area; adding the inset
            // again pushed Skip halfway down the logo.
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .animation(Motion.ease(0.25), value: page)
    }

    // MARK: - Page 1

    private var hookPage: some View {
        GeometryReader { geo in
            let dock = DockMetrics(height: geo.size.height)
            ZStack {
                SkyBackground(horizon: 0.5)
                AmbientEmbers(count: 16, tint: VV.sulfur, speed: 0.8, seed: 11)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Image("logo_volcvein_stacked")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: min(geo.size.width * 0.60, 230))
                        // Held at its natural height so the hero, not the logo,
                        // is what gives way on a short screen.
                        .fixedSize(horizontal: false, vertical: true)
                        .rotationEffect(.degrees(-2))
                        .shadow(color: VV.ink.opacity(0.42), radius: 22, x: 8, y: 14)
                        .padding(.top, 18)
                        .vvEntrance(0)

                    Image("onboard_hero_volcano")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .padding(.top, -8)
                        .ambientPulse(from: 0.99, to: 1.015, period: 5)
                        .vvEntrance(1)
                        // The one flexible piece: it takes the free height first
                        // and shrinks first, so the copy and controls never do.
                        .layoutPriority(1)

                    Spacer(minLength: 4)

                    PaperPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("A mountain you steer\nby closing doors")
                                .font(VV.display(28))
                                .textCase(.uppercase)
                                .foregroundStyle(VV.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Magma climbs a branching vein network toward the rim. You cannot push it, aim it, or pour it. **You can only shut branches** — and everything you shut starts to cool.")
                                .font(VV.body(14))
                                .foregroundStyle(VV.paperText3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 18)
                    .vvEntrance(2)

                    VStack(spacing: 0) {
                        pager(padding: dock.pagerPadding)
                        nextPlate(title: "Go on", metrics: dock) { page = 1 }
                            .vvEntrance(3)
                    }
                    // The insets DockedScroll gives page 2's dock, so the pager
                    // and plate hold still through the crossfade.
                    .padding(.horizontal, VV.s3)
                    .padding(.top, VV.s1)
                    .padding(.bottom, VV.s2)
                }
            }
        }
    }

    // MARK: - Page 2

    private var rulesPage: some View {
        GeometryReader { geo in
            let dock = DockMetrics(height: geo.size.height)
            ZStack {
                RockBackground()
                AmbientEmbers(count: 14, tint: VV.magmaHot, speed: 0.7, seed: 12)
                    .ignoresSafeArea()

                // The pager and plate are pinned; the rules take what is left
                // and only scroll on a screen too short to hold them.
                DockedScroll(dockSpacing: 0) { viewport in
                    rulesColumn(RulesLayout(viewport: viewport))
                } dock: {
                    pager(padding: dock.pagerPadding)
                    nextPlate(title: "Light the rift", metrics: dock) {
                        Haptics.success()
                        onFinish()
                    }
                }
            }
        }
    }

    private func rulesColumn(_ layout: RulesLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            HStack(spacing: 0) {
                rulesTitle(layout)
                // Keeps the slab clear of the Skip chip floating top-right.
                Spacer(minLength: 64)
            }
            .padding(.top, layout.topInset)
            .padding(.bottom, layout.titleGap)

            rulePanel(number: "1", head: "Shut, never ", accent: "steer",
                      accentColor: VV.magma, layout: layout,
                      body: "Tap a valve and that branch closes. Pressure has to go somewhere, so **everything upstream doubles down the branches you left open**.") {
                Image("diagram_shut_reroutes")
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .frame(height: layout.diagramHeight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, layout.diagramInset)
                    .background(Color(hex: 0x3A1206))
                    .padding(.top, 4)
            }

            rulePanel(number: "2", head: "Shut veins ", accent: "crust",
                      accentColor: VV.obsidianLit, rail: VV.obsidianLit, layout: layout,
                      body: "A closed branch cools. After a few seconds it seals for good — unless you **press and hold** to blow the crust out, which costs a bite of chamber pressure.") { EmptyView() }

            rulePanel(number: "3", head: "Fill the ", accent: "rim molds",
                      accentColor: VV.magma, rail: VV.magma, layout: layout,
                      body: "Every vent ends in a stone mold. Fill them all and the rift casts an obsidian piece. **Flood one and it cracks; starve one and it sets solid.**") { EmptyView() }
        }
    }

    /// The rotated ink slab. Two lines set tighter than the face's own leading,
    /// as in the mockup, with the keyword inked sulfur.
    private func rulesTitle(_ layout: RulesLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.titleLeading) {
            Text("Three ") + Text("rules").foregroundColor(VV.sulfur)
            Text("of the rift")
        }
        .font(VV.display(layout.titleSize))
        .textCase(.uppercase)
        .foregroundStyle(VV.ash)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16)
        .padding(.top, RulesLayout.slabTop)
        .padding(.bottom, RulesLayout.slabBottom)
        .background(VV.ink)
        .overlay(alignment: .leading) { Rectangle().fill(VV.magma).frame(width: 6) }
        .compositingGroup()
        .rotationEffect(.degrees(-1.6))
        .shadow(color: VV.ink.opacity(0.34), radius: 0, x: 7, y: 7)
        .padding(.leading, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func rulePanel<Extra: View>(number: String, head: String, accent: String,
                                        accentColor: Color, rail: Color = VV.sulfur,
                                        layout: RulesLayout,
                                        body text: String,
                                        @ViewBuilder extra: () -> Extra) -> some View {
        PaperPanel(rail: rail, padding: layout.panelPadding) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 0) {
                    Text("\(number) · \(head)")
                        .font(VV.display(layout.headSize))
                        .foregroundStyle(VV.ink)
                    Text(accent)
                        .font(VV.display(layout.headSize))
                        .foregroundStyle(accentColor)
                }
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(.init(text))
                    .font(VV.body(13))
                    .foregroundStyle(VV.paperText3)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
            }
        }
    }

    // MARK: - Controls

    private func pager(padding: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                Rectangle()
                    .fill(i == page ? VV.sulfur : VV.ash.opacity(0.32))
                    .frame(width: i == page ? 44 : 26, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, padding)
    }

    private func nextPlate(title: String, metrics: DockMetrics,
                           action: @escaping () -> Void) -> some View {
        FissurePlate(title: title, height: metrics.plateHeight, titleSize: metrics.plateTitleSize) {
            Haptics.knock()
            action()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, metrics.foot)
    }

    // MARK: - Layout metrics

    /// Pager and plate sizing, shared by both pages so the controls sit in the
    /// same place through the crossfade. `height` is the page's safe-area height.
    private struct DockMetrics {
        let height: CGFloat

        /// SE-class screens: a slimmer plate buys the rules their room.
        private var short: Bool { height < 700 }

        var pagerPadding: CGFloat { short ? 6 : 10 }
        var plateHeight: CGFloat { short ? 66 : 78 }
        var plateTitleSize: CGFloat { short ? 30 : 32 }
        /// Air under the plate on top of the dock's own inset — more where the
        /// screen can spare it, and enough on a home-button phone to clear the edge.
        var foot: CGFloat { short ? 6 : (height >= 820 ? 12 : 4) }
    }

    /// Page 2's measurements for the height the dock leaves it. Stepped so the
    /// title and all three rules sit above the dock without scrolling from a
    /// 402×874 phone up, and on an SE too once the diagram has given way.
    private struct RulesLayout {
        let viewport: CGFloat

        static let slabTop: CGFloat = 4
        static let slabBottom: CGFloat = 2

        private var compact: Bool { viewport < 600 }
        private var roomy: Bool { viewport >= 700 }

        var topInset: CGFloat { compact ? 6 : (roomy ? 14 : 8) }
        var titleSize: CGFloat { compact ? 34 : 40 }
        var titleGap: CGFloat { compact ? 2 : (roomy ? 6 : 4) }
        var spacing: CGFloat { compact ? 8 : (roomy ? 12 : 10) }
        var panelPadding: CGFloat { compact ? 12 : (roomy ? VV.s3 : 14) }
        var headSize: CGFloat { compact ? 21 : 23 }
        var diagramInset: CGFloat { compact ? 4 : (roomy ? 10 : 8) }

        /// Pulls the title's two lines together to the mockup's tight leading.
        var titleLeading: CGFloat { -titleSize * 0.4 }

        /// The diagram gets whatever the text leaves, between the size where its
        /// TAP label still reads and the size it was drawn at.
        var diagramHeight: CGFloat {
            min(96, max(56, viewport - columnWithoutDiagram))
        }

        /// The column minus the diagram art: title slab, three headed three-line
        /// paragraphs, the gaps, the diagram's frame, the dock's 14pt fade and a
        /// few points of slack for text that sets a hair taller on device.
        private var columnWithoutDiagram: CGFloat {
            let lineHeight: CGFloat = 1.366   // Avenir Next line height per point of size
            let slab: CGFloat = titleSize * lineHeight * 2 + titleLeading
                + Self.slabTop + Self.slabBottom
            let panel: CGFloat = panelPadding * 2 + headSize * lineHeight + 5
                + 13 * lineHeight * 3
            let diagramFrame: CGFloat = 5 + 4 + diagramInset * 2
            let title: CGFloat = topInset + slab + titleGap
            let panels: CGFloat = spacing * 3 + panel * 3 + diagramFrame
            return title + panels + 14 + 6
        }
    }
}
