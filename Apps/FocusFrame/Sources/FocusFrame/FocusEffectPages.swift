import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI

extension FocusSettingsView {
    func appearancePage() -> AnyView {
        page([
            section("Profile", [
                AnyView(Menu("Profil auswählen …") { ForEach(store.profiles.indices, id: \.self) { i in
                    Button(store.profiles[i].name) { model.mutate { $0 = store.profiles[i].appearance } }
                }}),
                actionButton("Darstellung als Profil speichern …", action: model.saveProfile),
                actionButton("Einstellungen exportieren …", action: model.exportPreferences),
                actionButton("Einstellungen importieren …", action: model.importPreferences)
            ]),
            section("Rahmen", [
                effectChoice("Rahmenposition", \.placement, [("Außen",.outside),("Mittig",.centered),("Innen",.inside)]),
                note("Bei Innen liegt der Abstand innerhalb des Fensters, sonst außerhalb."),
                conditional([AnyView(ColorPicker("Rahmenfarbe", selection: Binding(get: {
                    Color(nsColor: NSColor(srgbRed: store.value.appearance.red, green: store.value.appearance.green, blue: store.value.appearance.blue, alpha: 1))
                }, set: { color in
                    if let c = NSColor(color).usingColorSpace(.sRGB) { model.mutate { $0.red = c.redComponent; $0.green = c.greenComponent; $0.blue = c.blueComponent } }
                }), supportsOpacity: false))]) { $0.material.mode == .standard },
                effectSlider("Deckkraft", \.opacity, 10...100, percent: true), effectSlider("Stärke", \.width, 1...100),
                effectSlider("Eckenradius", \.radius, 0...300), effectSlider("Abstand", \.gap, 0...200),
                actionButton("Darstellung zurücksetzen", action: model.resetAppearance)
            ]),
            section("Oberfläche", [
                effectChoice("Oberfläche", \.material.mode, [("Farbe / Farbverlauf",.standard),("Gold",.gold),("Chrom",.chrome)]),
                conditional([effectSlider("Glanz", \.material.gloss, 0...100, percent: true),
                    effectSlider("Lichtwinkel", \.material.angle, 0...360, unit: "°"),
                    note("Gold und Chrom verwenden eigene Metallfarben. Rahmenfarbe und Farbverläufe bleiben gespeichert.")]) { $0.material.mode != .standard },
                resetEffect("Oberfläche zurücksetzen") { $0.material = MaterialEffect() }
            ])
        ])
    }
    func lightPage() -> AnyView {
        section("Leuchtmodus", [
            effectChoice("Leuchtmodus", \.light.mode, [("Aus",.off),("Glow",.glow),("Neon",.neon)]),
            conditional([
                effectSlider("Intensität", \.light.intensity, 0...100, percent: true),
                effectSlider("Leuchtweite", \.light.extent, 0...200),
                effectCheck("Rahmenfarbe übernehmen", \.light.followsFrame),
                conditional([effectColor("Eigene Leuchtfarbe", \.light.color)]) { !$0.light.followsFrame },
                conditional([
                    effectSlider("Kernstärke", \.light.coreWidth, 10...100, percent: true),
                    effectSlider("Aufhellung", \.light.whitening, 0...100, percent: true)
                ]) { $0.light.mode == .neon }
            ]) { $0.light.mode != .off },
            resetEffect("Leuchten zurücksetzen") { $0.light = LightEffect() }
        ])
    }

    func shadowPage() -> AnyView {
        section("Fensterschatten", [
            effectCheck("Schatten anzeigen", \.shadow.enabled),
            conditional([
                effectChoice("Farbe verwenden von", \.shadow.colorSource, [("Eigene Farbe",.custom),("Rahmenfarbe",.frame),("Rahmenverlauf",.gradient)]),
                conditional([effectColor("Eigene Farbe", \.shadow.color)]) { $0.shadow.colorSource == .custom },
                note( "Rahmenverlauf übernimmt die sichtbare Oberfläche. Ohne Verlauf wird die Rahmenfarbe verwendet."),
                effectSlider("Deckkraft", \.shadow.opacity, 0...100, percent: true),
                effectSlider("Weichheit", \.shadow.blur, 0...200),
                effectSlider("Ausbreitung", \.shadow.spread, 0...200),
                effectSlider("Versatz horizontal", \.shadow.offsetX, -200...200),
                effectSlider("Versatz vertikal", \.shadow.offsetY, -200...200)
            ]) { $0.shadow.enabled },
            resetEffect("Schatten zurücksetzen") { $0.shadow = ShadowEffect() }
        ])
    }

    func gradientPage() -> AnyView {
        section("Farben und Richtung", [
            conditional([note( "Aktuell wird Gold oder Chrom angezeigt. Wähle unter Darstellung die Oberfläche ‘Farbe / Farbverlauf’, um diese Farben wieder zu sehen.")]) { $0.material.mode != .standard },
            effectChoice("Farbverlauf", \.gradient.mode, [("Aus",.off),("Linear",.linear),("Umlaufend",.conic)]),
            conditional([
                AnyView(GradientStopEditor(gradient: store.value.appearance.gradient) { gradient in model.mutate { $0.gradient = gradient } }),
                effectSlider("Winkel / Startwinkel", \.gradient.angle, 0...360, unit: "°")
            ]) { $0.gradient.mode != .off },
            resetEffect("Farbverlauf zurücksetzen") { $0.gradient = GradientEffect() }
        ])
    }

    func animationPage() -> AnyView {
        let trigger: [(String,AnimationTrigger)] = [("Nur beim Fokuswechsel",.focus),("Dauerhaft",.continuous)]
        return page([
            section("Vorschau und Presets", [AnyView(FocusAnimationPreview(appearance: store.value.normalized.renderedAppearance(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled), playToken: model.playToken).frame(height: 190)),
                actionButton("Animation abspielen") { model.playToken += 1 },
                resetEffect("Dezent") { $0 = MotionPreset.subtle.applying(to: $0) },
                resetEffect("Lichtläufer") { $0 = MotionPreset.runner.applying(to: $0) },
                resetEffect("Atmender Schatten") { $0 = MotionPreset.breathingShadow.applying(to: $0) },
                resetEffect("Farbfluss") { $0 = MotionPreset.colorFlow.applying(to: $0) }
            ]),
            section("Bewegung", [
                effectChoice("Effekt", \.motion.mode, [("Aus",.off),("Fokusimpuls",.impulse),("Lichtläufer",.runner),("Rahmen zeichnen",.draw),("Atmen",.breathe),("Farbfluss",.flow)]),
                conditional([
                    effectChoice("Auslöser", \.motion.trigger, trigger),
                    effectSlider("Dauer je Durchlauf", \.motion.duration, 0.5...30, unit: "s"),
                    conditional([effectSlider("Durchläufe", \.motion.cycles, 1...6)]) { $0.motion.trigger == .focus },
                    effectSlider("Stärke", \.motion.strength, 0...100, percent: true),
                    effectChoice("Bewegungsverlauf", \.motion.curve, [("Sanft",.smooth),("Gleichmäßig",.linear),("Federnd (Impuls)",.spring)]),
                    conditional([effectChoice("Animieren", \.motion.target, [("Schatten",.shadow),("Rahmen",.frame),("Leuchten",.light),("Alles",.all)])]) { $0.motion.mode == .breathe },
                    note( "Farbfluss braucht einen aktiven Farbverlauf. Atmen wirkt auf das gewählte Element; ein Schatten oder Leuchten muss eingeschaltet sein.")
                ]) { $0.motion.mode != .off },
                effectCheck("Dauer und Auslöser für weitere Effekte übernehmen", \.motion.synchronize),
                note( "Bei gemeinsamer Steuerung gelten Dauer und Auslöser oben auch für Deckkraft, Rotation und Metallreflex. Die Einzelwerte bleiben gespeichert."),
                resetEffect("Bewegung zurücksetzen") { $0.motion = MotionEffect() }
            ]),
            section("Deckkraft", [
                effectChoice("Animieren", \.opacityAnimation.target, [("Alles",.all),("Rahmen",.frame),("Leuchten",.light),("Schatten",.shadow)]),
                effectChoice("Animation", \.opacityAnimation.mode, [("Aus",.off),("Pulsieren",.pulse),("Blinken",.blink)]),
                conditional([
                    conditional([
                        effectSlider("Zyklusdauer", \.opacityAnimation.pulsePeriod, 0.5...10, unit: "s"),
                        effectSlider("Minimum", \.opacityAnimation.pulseMinimum, 0...100, percent: true)
                    ]) { $0.opacityAnimation.mode == .pulse },
                    conditional([
                        effectSlider("Zyklusdauer", \.opacityAnimation.blinkPeriod, 0.5...5, unit: "s"),
                        effectSlider("Minimum", \.opacityAnimation.blinkMinimum, 0...100, percent: true)
                    ]) { $0.opacityAnimation.mode == .blink },
                    effectSlider("Maximum", \.opacityAnimation.maximum, 0...100, percent: true),
                    effectChoice("Auslöser", \.opacityAnimation.trigger, trigger),
                    conditional([effectSlider("Fokusdauer", \.opacityAnimation.focusDuration, 0.5...5, unit: "s")]) {
                        $0.opacityAnimation.trigger == .focus
                    }
                ]) { $0.opacityAnimation.mode != .off },
                resetEffect("Deckkraftanimation zurücksetzen") { $0.opacityAnimation = OpacityEffect() }
            ]),
            section("Verlaufsrotation", [
                effectCheck("Farbverlauf rotieren", \.rotation.enabled),
                conditional([
                    effectSlider("Umlaufdauer", \.rotation.period, 2...30, unit: "s"),
                    effectCheck("Im Uhrzeigersinn", \.rotation.clockwise),
                    effectChoice("Auslöser", \.rotation.trigger, trigger),
                    conditional([effectSlider("Fokusdauer", \.rotation.focusDuration, 0.5...5, unit: "s")]) {
                        $0.rotation.trigger == .focus
                    },
                    note( "Rotation benötigt einen eingeschalteten Farbverlauf und die Oberfläche ‘Farbe / Farbverlauf’.")
                ]) { $0.rotation.enabled },
                resetEffect("Verlaufsrotation zurücksetzen") { $0.rotation = RotationEffect() }
            ]),
            section("Metall-Lichtreflex", [
                conditional([note( "Für den Lichtreflex Gold oder Chrom unter Darstellung wählen.")]) { $0.material.mode == .standard },
                conditional([
                    effectCheck("Lichtreflex bewegen", \.material.reflectionEnabled),
                    conditional([
                        effectSlider("Reflexstärke", \.material.reflectionStrength, 0...100, percent: true),
                        effectSlider("Reflexbreite", \.material.reflectionWidth, 5...60, percent: true),
                        effectChoice("Auslöser", \.material.trigger, trigger),
                        conditional([effectSlider("Zyklusdauer", \.material.period, 2...30, unit: "s")]) { $0.material.trigger == .continuous },
                        conditional([effectSlider("Fokusdauer", \.material.focusDuration, 0.5...5, unit: "s")]) { $0.material.trigger == .focus }
                    ]) { $0.material.reflectionEnabled }
                ]) { $0.material.mode != .standard },
                resetEffect("Lichtreflex zurücksetzen") { a in
                    let d = MaterialEffect()
                    a.material.reflectionEnabled = d.reflectionEnabled
                    a.material.reflectionStrength = d.reflectionStrength; a.material.reflectionWidth = d.reflectionWidth
                    a.material.period = d.period; a.material.trigger = d.trigger; a.material.focusDuration = d.focusDuration
                }
            ]),
            actionButton("Fokuswechsel testen") { model.testFocus?() },
            note( "Bei macOS ‘Bewegung reduzieren’ bleiben Effekte statisch.")
        ], inset: 0)
    }
    func page(_ views: [AnyView], inset: CGFloat = 0) -> AnyView {
        AnyView(VStack(alignment: .leading, spacing: KitSpacing.group) { ForEach(views.indices, id: \.self) { views[$0] } })
    }
    func section(_ title: String, _ views: [AnyView]) -> AnyView { AnyView(SettingsSection(title) { page(views) }) }
    func note(_ text: String) -> AnyView { AnyView(StatusMessage(text)) }
    func actionButton(_ title: String, action: @escaping () -> Void) -> AnyView { AnyView(Button(title, action: action)) }
    func conditional(_ views: [AnyView], when visible: (Appearance) -> Bool) -> AnyView { visible(store.value.appearance) ? page(views) : AnyView(EmptyView()) }
    func resetEffect(_ title: String, _ change: @escaping (inout Appearance) -> Void) -> AnyView { actionButton(title) { model.mutate(change) } }
    func effectSlider(_ title: String, _ key: WritableKeyPath<Appearance, Double>, _ range: ClosedRange<Double>, percent: Bool = false, unit: String = "pt") -> AnyView {
        let scale = percent ? 100.0 : 1.0
        return AnyView(SliderRow(title, value: Binding(get: { store.value.appearance[keyPath: key] * scale }, set: { v in model.mutate { $0[keyPath: key] = v / scale } }), in: range, unit: percent ? "%" : unit))
    }
    func effectCheck(_ title: String, _ key: WritableKeyPath<Appearance, Bool>) -> AnyView {
        AnyView(ToggleRow(title, isOn: Binding(get: { store.value.appearance[keyPath: key] }, set: { v in model.mutate { $0[keyPath: key] = v } })))
    }
    func effectChoice<T: Hashable>(_ title: String, _ key: WritableKeyPath<Appearance, T>, _ choices: [(String,T)]) -> AnyView {
        AnyView(ChoiceRow(title, selection: Binding(get: { store.value.appearance[keyPath: key] }, set: { v in model.mutate { a in
            if title == "Farbverlauf", a.gradient.mode == .off { a.gradient.stops[0].color = EffectColor(a.red,a.green,a.blue) }
            a[keyPath: key] = v
        }}), options: choices))
    }
    func effectColor(_ title: String, _ key: WritableKeyPath<Appearance, EffectColor>) -> AnyView {
        AnyView(ColorPicker(title, selection: Binding(get: { Color(nsColor: store.value.appearance[keyPath: key].nsColor) }, set: { color in
            if let c = NSColor(color).usingColorSpace(.sRGB) { model.mutate { $0[keyPath: key] = EffectColor(c.redComponent,c.greenComponent,c.blueComponent) } }
        }), supportsOpacity: false))
    }
}
