//
//  ContentView.swift
//  ValorCerto
//
//  Created by Cássio on 01/05/26.
//

import AVFoundation
import CoreImage
import ImageIO
import StoreKit
import SwiftUI
import UIKit

/// ID do produto na App Store Connect (subscrição anual “sem anúncios”).
enum ValorSubscriptionProductID {
    static let removeAdsAnnual = "com.corevo.ValorCerto.removeads.annual"
}

enum ValorTheme {
    static let purple = Color(red: 0.58, green: 0.42, blue: 0.90)
    static let softPurple = Color(red: 0.87, green: 0.80, blue: 0.96)
    static let softBlue = Color(red: 0.84, green: 0.90, blue: 0.98)
    static let mint = Color(red: 0.54, green: 0.90, blue: 0.74)
    static let mintStrong = Color(red: 0.40, green: 0.82, blue: 0.66)
    static let ink = Color(red: 0.22, green: 0.20, blue: 0.33)
    static let textPrimary = Color(red: 0.18, green: 0.16, blue: 0.28)
    static let textSecondary = Color(red: 0.36, green: 0.33, blue: 0.49)

    static let primaryGradient = LinearGradient(
        colors: [purple, Color(red: 0.72, green: 0.60, blue: 0.93)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [mint, mintStrong],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenGradient = LinearGradient(
        colors: [softPurple.opacity(0.82), softPurple.opacity(0.68)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Superfície de cards (menu, histórico): branco / quase branco
    static let cardSurfaceLight = LinearGradient(
        colors: [
            Color.white.opacity(0.98),
            Color(red: 0.98, green: 0.98, blue: 1.0).opacity(0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Inset horizontal do menu inferior e do card de consulta (mesma largura visível).
private enum ValorLayout {
    static let mainPanelHorizontalInset: CGFloat = 16
    /// Espaço entre o card de resultado e o card do código de barras.
    static let gapResultAboveBarcode: CGFloat = 12
}

/// Voltar em telas empilhadas a partir do Menu (tab bar oculto).
private struct MenuStackBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.42))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voltar")
    }
}

/// Campo de código de barras: SF Rounded + semibold, coerente com o resto do UI.
private func valorBarcodeTextFieldFont() -> UIFont {
    let size: CGFloat = 18
    let base = UIFont.systemFont(ofSize: size, weight: .semibold)
    let rounded: UIFont
    if let d = base.fontDescriptor.withDesign(.rounded) {
        rounded = UIFont(descriptor: d, size: size)
    } else {
        rounded = base
    }
    return UIFontMetrics(forTextStyle: .body).scaledFont(for: rounded, maximumPointSize: 24)
}

/// Altura coberta pelo teclado / inputView acima da área de conteúdo (acima do `safeAreaInset` do menu).
private func keyboardOverlapAboveContent(
    keyboardFrameInScreen: CGRect,
    window: UIWindow,
    contentSafeAreaBottom: CGFloat
) -> CGFloat {
    let kb = window.convert(keyboardFrameInScreen, from: nil)
    let coveredFromWindowBottom = window.bounds.maxY - kb.minY
    return max(0, coveredFromWindowBottom - contentSafeAreaBottom)
}

struct ContentView: View {
    @StateObject private var appModel = AppModel()
    @State private var showSplash = true
    @State private var selectedTab: HomeTab = .scan

    var body: some View {
        ZStack {
            Group {
                switch selectedTab {
                case .history:
                    HistoryScreen()
                        .environmentObject(appModel)
                case .scan:
                    ScannerScreen()
                        .environmentObject(appModel)
                case .menu:
                    SettingsScreen()
                        .environmentObject(appModel)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: ValorLayout.mainPanelHorizontalInset) {
                if !appModel.suppressBottomMenuBar {
                    BottomMenuBar(
                        selectedTab: $selectedTab,
                        onScanTap: {
                            selectedTab = .scan
                            appModel.isScannerPresented = true
                        }
                    )
                }
            }
            .onChange(of: selectedTab) { _, _ in
                appModel.suppressBottomMenuBar = false
            }
            .disabled(showSplash)

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .task {
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            withAnimation(.easeOut(duration: 0.28)) {
                showSplash = false
            }
        }
    }
}

enum HomeTab {
    case history
    case scan
    case menu
}

struct BottomMenuBar: View {
    @Binding var selectedTab: HomeTab
    let onScanTap: () -> Void

    var body: some View {
        HStack(spacing: 34) {
            bottomButton(
                title: "Histórico",
                systemImage: "clock.arrow.circlepath",
                tab: .history
            )

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    onScanTap()
                }
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.title.weight(.bold))
                    .imageScale(.large)
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(ValorTheme.accentGradient)
                    .clipShape(Circle())
                    .shadow(color: ValorTheme.mintStrong.opacity(0.38), radius: 14, y: 7)
            }
            .offset(y: -20)

            bottomButton(
                title: "Menu",
                systemImage: "line.3.horizontal",
                tab: .menu
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(tabBarGlassShape)
        .shadow(color: ValorTheme.purple.opacity(0.18), radius: 10, y: 4)
        .padding(.horizontal, ValorLayout.mainPanelHorizontalInset)
        .padding(.bottom, 6)
    }

    private var tabBarGlassShape: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(ValorTheme.purple.opacity(0.18), lineWidth: 1)
            )
    }

    private func bottomButton(
        title: String,
        systemImage: String,
        tab: HomeTab
    ) -> some View {
        let isSelected = selectedTab == tab
        let active = ValorTheme.purple
        let inactive = Color(red: 0.38, green: 0.36, blue: 0.44).opacity(0.45)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? active : inactive)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? active : inactive)
            }
            .frame(width: 72)
            .padding(.vertical, 6)
        }
    }
}

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.82
    @State private var logoOpacity = 0.0

    var body: some View {
        ZStack {
            Image("MenuSplashBackground")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .all)

            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 210)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                        logoScale = 1
                    }
                    withAnimation(.easeOut(duration: 0.22)) {
                        logoOpacity = 1
                    }
                }
        }
    }
}

struct ScannerScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var manualBarcode = ""
    @State private var lastResult: PriceCheckResponse?
    @State private var isFetchingPrice = false
    @State private var consultaErro: String?
    /// Fundo seguro inferior da área principal (inclui altura do `safeAreaInset` do menu).
    @State private var contentSafeAreaBottom: CGFloat = 0
    /// Elevação extra para o card ficar acima do teclado / teclado personalizado.
    @State private var keyboardOverlapInset: CGFloat = 0

    /// Altura do preview da câmera (~30% menor que o valor base de 320 pt).
    private let scannerPreviewHeight: CGFloat = 320 * 0.7

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Image("HomeBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .all)
                    .ignoresSafeArea(.keyboard, edges: .all)

                GeometryReader { geo in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(spacing: ValorLayout.gapResultAboveBarcode) {
                            if let consultaErro {
                                Text(consultaErro)
                                    .font(.footnote)
                                    .foregroundStyle(.red.opacity(0.92))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if isFetchingPrice {
                                skeletonBlock
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            } else if let lastResult {
                                priceResultCard(lastResult)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            VStack(spacing: 16) {
                                if appModel.isScannerPresented {
                                VStack(spacing: 0) {
                                    BarcodeScannerView { code in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            appModel.isScannerPresented = false
                                        }
                                        appModel.pendingBarcode = code
                                    }
                                    .frame(height: scannerPreviewHeight)
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                appModel.isScannerPresented = false
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(.white)
                                                .padding(10)
                                        }
                                    }
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(ValorTheme.mint.opacity(0.55), lineWidth: 1.5)
                                }
                                .padding(.bottom, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                HStack(alignment: .center, spacing: 10) {
                                ZStack(alignment: .leading) {
                                    if manualBarcode.isEmpty {
                                        Text("Digite código de barras")
                                            .font(.system(.body, design: .rounded))
                                            .fontWeight(.medium)
                                            .foregroundStyle(ValorTheme.textSecondary.opacity(0.88))
                                            .padding(.horizontal, 14)
                                    }
                                    BarcodeKeypadField(text: $manualBarcode) { isEditing in
                                        if isEditing {
                                            if appModel.isScannerPresented {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    appModel.isScannerPresented = false
                                                }
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                if keyboardOverlapInset < 2 {
                                                    withAnimation(.easeOut(duration: 0.25)) {
                                                        keyboardOverlapInset = 280
                                                    }
                                                }
                                            }
                                        }
                                    }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 0)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white.opacity(0.9))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(ValorTheme.softPurple.opacity(0.35), lineWidth: 1)
                                }

                                Button {
                                    dismissScannerKeyboard()
                                    Task { await runPriceCheck() }
                                } label: {
                                    Group {
                                        if isFetchingPrice {
                                            ProgressView()
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                                                .font(.system(size: 22, weight: .semibold))
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .background(
                                    LinearGradient(
                                        colors: [ValorTheme.purple, ValorTheme.mintStrong],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: ValorTheme.purple.opacity(0.35), radius: 10, y: 6)
                                .disabled(isFetchingPrice)
                                .accessibilityLabel("Consultar valor")
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.white.opacity(0.76))
                            )
                            .shadow(color: ValorTheme.purple.opacity(0.12), radius: 16, y: 8)
                        }
                        .padding(.horizontal, ValorLayout.mainPanelHorizontalInset)
                        .padding(
                            .bottom,
                            bottomPaddingAboveTabBar(
                                keyboardOverlap: keyboardOverlapInset,
                                safeBottom: geo.safeAreaInsets.bottom
                            )
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        contentSafeAreaBottom = geo.safeAreaInsets.bottom
                    }
                    .onChange(of: geo.safeAreaInsets.bottom) { _, newValue in
                        contentSafeAreaBottom = newValue
                    }
                }
                .zIndex(3)

                Image("HomeBrandLogo")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 420, maxHeight: 240)
                    .accessibilityLabel("ValorCerto")
                    .zIndex(1)

                Color.clear
                    .frame(minHeight: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissScannerKeyboard()
                    }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appModel.pendingBarcode) { _, newValue in
            guard let newValue else { return }
            manualBarcode = newValue
            appModel.pendingBarcode = nil
            Task { await runPriceCheck() }
        }
        .animation(.easeInOut(duration: 0.24), value: isFetchingPrice)
        .animation(.easeInOut(duration: 0.24), value: lastResult?.id)
        .animation(.easeInOut(duration: 0.24), value: appModel.isScannerPresented)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            updateKeypadOverlap(from: note)
        }
    }

    private func updateKeypadOverlap(from notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            keyboardOverlapInset = 0
            return
        }
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        guard let window else {
            keyboardOverlapInset = 0
            return
        }

        let overlap = keyboardOverlapAboveContent(
            keyboardFrameInScreen: frame,
            window: window,
            contentSafeAreaBottom: contentSafeAreaBottom
        )

        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?
            .doubleValue ?? 0.25

        withAnimation(.easeOut(duration: duration)) {
            keyboardOverlapInset = overlap
        }
    }

    private func dismissScannerKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// Espaço abaixo do card de código de barras: margem + folga acima do menu; com teclado, só margem + sobreposição.
    private func bottomPaddingAboveTabBar(keyboardOverlap: CGFloat, safeBottom: CGFloat) -> CGFloat {
        let margin = ValorLayout.mainPanelHorizontalInset
        let gapAboveMenu: CGFloat = 12

        if keyboardOverlap > 2 {
            return margin + keyboardOverlap
        }

        // Se o safe bottom não reflete o `safeAreaInset` da BottomMenuBar, reserva altura típica da barra para o card não ficar atrás dela.
        let fallbackTabChrome: CGFloat = safeBottom < 44 ? 88 : 0

        return margin + gapAboveMenu + fallbackTabChrome
    }

    private var skeletonBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.25))
                .frame(height: 20)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.25))
                .frame(height: 20)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 60)
        }
        .padding()
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func runPriceCheck() async {
        let code = manualBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            consultaErro = nil
            return
        }

        isFetchingPrice = true
        consultaErro = nil
        defer { isFetchingPrice = false }

        do {
            let result = try await appModel.apiClient.priceCheck(
                barcode: code,
                userPrice: nil
            )

            lastResult = result
            appModel.saveToHistory(result)
        } catch {
            consultaErro = friendlyPriceCheckError(error)
        }
    }

    private func friendlyPriceCheckError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Sem ligação à internet. Verifica a rede e tenta de novo."
            case .timedOut:
                return "O pedido expirou. Tenta de novo."
            case .badServerResponse:
                return "O servidor devolveu uma resposta inválida. Tenta de novo em instantes."
            default:
                break
            }
        }
        if let api = error as? APIClientError {
            return api.userFacingMessage
        }
        if error is DecodingError {
            return "Resposta do servidor em formato inesperado. Atualiza a app ou tenta dentro de momentos."
        }
        return "Erro na consulta: \(error.localizedDescription)"
    }

    @ViewBuilder
    private func priceResultCard(_ lastResult: PriceCheckResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lastResult.name)
                .font(.headline)
                .foregroundStyle(ValorTheme.textPrimary)

            if lastResult.compared {
                HStack(spacing: 8) {
                    Text(lastResult.statusIcon)
                        .font(.title2)
                    Text(lastResult.statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(lastResult.statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    (lastResult.status ?? "").lowercased() == "barato"
                    ? ValorTheme.mint.opacity(0.2)
                    : lastResult.statusColor.opacity(0.1)
                )
                .clipShape(Capsule())

                VStack(spacing: 8) {
                    if let user = lastResult.user_price {
                        resultRow(title: "Você pagou", value: user.currencyBRL)
                    }
                    resultRow(title: "Média", value: lastResult.average_price.currencyBRL)
                    if let diff = lastResult.difference_percent {
                        resultRow(title: "Diferença", value: "\(diff)%")
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text(lastResult.statusIcon)
                        .font(.title2)
                    Text("Valor médio de mercado")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ValorTheme.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ValorTheme.softPurple.opacity(0.45))
                .clipShape(Capsule())

                VStack(spacing: 8) {
                    resultRow(title: "Média", value: lastResult.average_price.currencyBRL)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ValorTheme.softPurple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: ValorTheme.purple.opacity(0.1), radius: 8, y: 4)
    }

    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(ValorTheme.textSecondary)
                .font(.subheadline)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(ValorTheme.textPrimary)
                .font(.subheadline)
        }
    }
}

struct HistoryScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showClearHistoryConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Image("MenuSplashBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                Group {
                    if appModel.history.isEmpty {
                        VStack(spacing: 14) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(ValorTheme.purple.opacity(0.55))
                            Text("Sem histórico")
                                .font(.headline)
                                .foregroundStyle(ValorTheme.ink)
                            Text("As consultas recentes aparecerão aqui.")
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(ValorTheme.textSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(historyCardChrome())
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                HStack {
                                    Spacer(minLength: 0)
                                    Button {
                                        showClearHistoryConfirm = true
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "trash")
                                            Text("Limpar histórico")
                                        }
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(
                                            ValorTheme.textSecondary.opacity(0.72)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Pede confirmação antes de apagar tudo")
                                }
                                .padding(.horizontal, 4)

                                ForEach(appModel.history) { item in
                                    HistoryRowChrome(
                                        title: item.name,
                                        barcode: item.barcode,
                                        averageFormatted: item.average_price.currencyBRL,
                                        statusText: item.compared ? item.statusText : "Média de mercado",
                                        statusColor: item.compared ? item.statusColor : ValorTheme.purple,
                                        onDelete: { appModel.removeHistoryItem(id: item.id) }
                                    )
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity
                                        )
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        }
                        .scrollIndicators(.hidden)
                        .animation(.smooth(duration: 0.28), value: appModel.history.count)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if showClearHistoryConfirm {
                    historyClearConfirmOverlay
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .animation(.easeOut(duration: 0.22), value: showClearHistoryConfirm)
        }
    }

    private var historyClearConfirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    showClearHistoryConfirm = false
                }

            VStack(spacing: 18) {
                Text("Limpar histórico?")
                    .font(.headline)
                    .foregroundStyle(ValorTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(
                    "Esta ação não pode ser desfeita. Todas as consultas guardadas neste aparelho serão apagadas."
                )
                .font(.subheadline)
                .foregroundStyle(ValorTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        showClearHistoryConfirm = false
                    } label: {
                        Text("Cancelar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ValorTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .strokeBorder(ValorTheme.softPurple.opacity(0.45), lineWidth: 1)
                                    .background(Capsule().fill(Color.white.opacity(0.55)))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        appModel.clearHistory()
                        showClearHistoryConfirm = false
                    } label: {
                        Text("Excluir tudo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.78))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ValorTheme.cardSurfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(ValorTheme.softPurple.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: ValorTheme.purple.opacity(0.18), radius: 18, y: 10)
            .padding(.horizontal, 28)
        }
    }

    private func historyCardChrome() -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(ValorTheme.cardSurfaceLight)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(ValorTheme.softPurple.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: ValorTheme.purple.opacity(0.14), radius: 10, y: 6)
    }
}

private struct HistoryRowChrome: View {
    let title: String
    let barcode: String
    let averageFormatted: String
    let statusText: String
    let statusColor: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(ValorTheme.ink)
                Text("Código: \(barcode)")
                    .font(.caption)
                    .foregroundStyle(ValorTheme.purple.opacity(0.62))
                HStack {
                    Text("Média: \(averageFormatted)")
                        .foregroundStyle(ValorTheme.ink.opacity(0.85))
                        .fontWeight(.medium)
                    Spacer()
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ValorTheme.softPurple.opacity(0.2))
                        .clipShape(Capsule())
                }
                .font(.subheadline)
            }
            Spacer(minLength: 6)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ValorTheme.purple.opacity(0.72))
                    .padding(8)
                    .background(ValorTheme.softPurple.opacity(0.25))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ValorTheme.cardSurfaceLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ValorTheme.softPurple.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: ValorTheme.purple.opacity(0.14), radius: 10, y: 6)
    }
}

struct RemoveAdsSubscriptionScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var storeProduct: Product?
    @State private var isLoadingProduct = true
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var bannerMessage: String?
    @State private var showBanner = false

    private var priceLine: String {
        if let storeProduct {
            return "\(storeProduct.displayPrice) / ano"
        }
        return "R$ 19,90 / ano"
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image("MenuSplashBackground")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .all)
                .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    if appModel.removeAdsPurchased {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(ValorTheme.mintStrong)
                            Text("Estás sem anúncios. Obrigado por apoiar o ValorCerto.")
                                .font(.subheadline)
                                .foregroundStyle(ValorTheme.ink)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.45), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Experiência sem anúncios")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                        Text("Subscrição anual com renovação automática. Cancele quando quiser nas definições da sua Apple ID.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        labelRow(icon: "rectangle.slash", text: "Sem banners nem interrupções ao comparar preços")
                        labelRow(icon: "sparkles", text: "Interface mais limpa e rápida")
                        labelRow(icon: "heart.fill", text: "Apoia a Corevo startup")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.33))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )

                    VStack(spacing: 6) {
                        Text(priceLine)
                            .font(.title.weight(.bold))
                            .foregroundStyle(ValorTheme.mintStrong)
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                        Text("cobrança anual · renovação automática")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    if isLoadingProduct {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        Task { await purchase() }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(appModel.removeAdsPurchased ? "Subscrição ativa" : "Continuar para pagamento")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background {
                            if appModel.removeAdsPurchased {
                                Color.gray.opacity(0.45)
                            } else {
                                ValorTheme.accentGradient
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .disabled(appModel.removeAdsPurchased || isPurchasing || isLoadingProduct)

                    Button {
                        Task { await restorePurchases() }
                    } label: {
                        Text("Restaurar compras")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(isRestoring || isPurchasing)

                    Text(
                        "O pagamento é processado pela Apple. Precisas de criar o produto de subscrição com este ID na App Store Connect: \(ValorSubscriptionProductID.removeAdsAnnual)."
                    )
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .padding(.top, geo.safeAreaInsets.top + 54)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topLeading) {
            MenuStackBackButton()
                .padding(.leading, 12)
                .safeAreaPadding(.top, 8)
        }
        .onAppear {
            appModel.suppressBottomMenuBar = true
        }
        .onDisappear {
            appModel.suppressBottomMenuBar = false
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("ValorCerto", isPresented: $showBanner, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(bannerMessage ?? "")
        })
        .task {
            await loadProduct()
            await appModel.refreshRemoveAdsEntitlement()
        }
    }

    private func labelRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ValorTheme.mintStrong)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.95))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }

    private func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        let ids = [ValorSubscriptionProductID.removeAdsAnnual]
        guard let products = try? await Product.products(for: ids) else { return }
        storeProduct = products.first
    }

    private func purchase() async {
        guard !appModel.removeAdsPurchased else { return }
        if let storeProduct {
            isPurchasing = true
            defer { isPurchasing = false }
            do {
                let result = try await storeProduct.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        if transaction.productID == ValorSubscriptionProductID.removeAdsAnnual {
                            await transaction.finish()
                            appModel.setRemoveAdsPurchased(true)
                            bannerMessage = "Compra concluída. Anúncios removidos neste dispositivo."
                            showBanner = true
                        }
                    case .unverified(_, let error):
                        bannerMessage = error.localizedDescription
                        showBanner = true
                    }
                case .userCancelled:
                    break
                case .pending:
                    bannerMessage = "Compra pendente de aprovação (Ask to Buy ou similar)."
                    showBanner = true
                @unknown default:
                    break
                }
            } catch {
                bannerMessage = error.localizedDescription
                showBanner = true
            }
            return
        }

        bannerMessage =
            "Produto ainda não encontrado na App Store. Configura a subscrição anual na App Store Connect com o preço de R$ 19,90 e o ID \(ValorSubscriptionProductID.removeAdsAnnual)."
        showBanner = true
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await appModel.refreshRemoveAdsEntitlement()
            if appModel.removeAdsPurchased {
                bannerMessage = "Compras restauradas."
            } else {
                bannerMessage = "Não encontrámos uma subscrição ativa para esta Apple ID."
            }
            showBanner = true
        } catch {
            bannerMessage = error.localizedDescription
            showBanner = true
        }
    }
}

struct AboutScreen: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            Image("AboutBackground")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .all)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .all)
            .allowsHitTesting(false)

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 22) {
                        Image("AboutLogo")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280, maxHeight: 120)
                            .accessibilityLabel("ValorCerto")

                        Text(
                            "O objetivo do ValorCerto é facilitar a vida das pessoas e ajudar a garantir que você está fazendo uma compra com valor justo."
                        )
                        .font(.body)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)

                        Text("Desenvolvido pela Corevo startup.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.93, green: 0.90, blue: 1.0))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 28)
                    .frame(width: geo.size.width)
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .overlay(alignment: .topLeading) {
            MenuStackBackButton()
                .padding(.leading, 12)
                .safeAreaPadding(.top, 8)
        }
        .onAppear {
            appModel.suppressBottomMenuBar = true
        }
        .onDisappear {
            appModel.suppressBottomMenuBar = false
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Fundo `AboutBackground` + cartão em material (telas legais); a tela Sobre usa só imagem e texto.
private struct AboutChromePage<Content: View>: View {
    @EnvironmentObject private var appModel: AppModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Image("AboutBackground")
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .all)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .all)
            .allowsHitTesting(false)

            ScrollView {
                content()
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topLeading) {
            MenuStackBackButton()
                .padding(.leading, 12)
                .safeAreaPadding(.top, 8)
        }
        .onAppear {
            appModel.suppressBottomMenuBar = true
        }
        .onDisappear {
            appModel.suppressBottomMenuBar = false
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct PrivacyPolicyScreen: View {
    var body: some View {
        AboutChromePage {
            VStack(alignment: .leading, spacing: 18) {
                Text("Políticas de Privacidade")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("Última atualização: maio de 2026")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))

                legalSectionTitle("1. Introdução")
                legalParagraph(
                    "O ValorCerto respeita a sua privacidade. Esta política descreve como tratamos informações quando utiliza a aplicação."
                )

                legalSectionTitle("2. Dados que tratamos")
                legalParagraph(
                    "Consultas de código de barras que envia ao nosso serviço (código e, se indicar, preço de referência), respostas do servidor e, no seu dispositivo, histórico de consultas guardado localmente. Se usar compras na App Store, a Apple processa o pagamento segundo as regras da Apple."
                )

                legalSectionTitle("3. Finalidade")
                legalParagraph(
                    "Prestar a funcionalidade de consulta de preços e médias, melhorar o serviço e cumprir obrigações legais quando aplicável."
                )

                legalSectionTitle("4. Armazenamento e localização")
                legalParagraph(
                    "O histórico de consultas pode ser guardado apenas neste aparelho. Os pedidos à API são tratados conforme a configuração do backend (por exemplo, alojamento seguro). Não vendemos os seus dados pessoais."
                )

                legalSectionTitle("5. Alterações")
                legalParagraph(
                    "Podemos atualizar esta política. A data no topo indica a versão mais recente. O uso continuado da app após alterações constitui aceitação, salvo disposição legal em contrário."
                )

                legalSectionTitle("6. Contacto")
                legalParagraph(
                    "Para questões sobre privacidade no contexto da Corevo startup e do ValorCerto, contacte-nos através dos canais oficiais divulgados pela equipa."
                )
            }
        }
    }

    private func legalSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.top, 4)
    }

    private func legalParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.white.opacity(0.88))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct TermsOfUseScreen: View {
    var body: some View {
        AboutChromePage {
            VStack(alignment: .leading, spacing: 18) {
                Text("Termos de Uso")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)

                Text("Última atualização: maio de 2026")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.72))

                termsSectionTitle("1. Aceitação")
                termsParagraph(
                    "Ao utilizar o ValorCerto, concorda com estes termos. Se não concordar, não utilize a aplicação."
                )

                termsSectionTitle("2. Natureza do serviço")
                termsParagraph(
                    "O ValorCerto apresenta informações de referência (por exemplo, médias ou estimativas) baseadas em dados disponíveis ao serviço. Os preços reais nas lojas podem variar; a informação não constitui aconselhamento financeiro nem garantia de preço."
                )

                termsSectionTitle("3. Uso permitido")
                termsParagraph(
                    "Compromete-se a não utilizar a app de forma abusiva, ilegal ou que prejudique outros utilizadores ou infraestruturas (incluindo tentativas de acesso não autorizado)."
                )

                termsSectionTitle("4. Limitação de responsabilidade")
                termsParagraph(
                    "Na medida permitida pela lei aplicável, a Corevo startup e os seus colaboradores não respondem por danos indiretos ou consequenciais decorrentes do uso ou impossibilidade de uso da app. O serviço é prestado «tal como está»."
                )

                termsSectionTitle("5. Alterações e rescisão")
                termsParagraph(
                    "Podemos alterar estes termos ou descontinuar funcionalidades. O uso continuado após alterações relevantes pode significar aceitação dos novos termos, conforme permitido pela lei."
                )

                termsSectionTitle("6. Lei aplicável")
                termsParagraph(
                    "Para litígios, aplicam-se as leis portuguesas e os tribunais competentes, sem prejuízo de direitos imperativos do consumidor na UE."
                )
            }
        }
    }

    private func termsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.top, 4)
    }

    private func termsParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.white.opacity(0.88))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Image("MenuSplashBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .all)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 18) {
                    menuCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Conexão do backend")
                                .font(.headline)
                                .foregroundStyle(ValorTheme.textPrimary)

                            Text(appModel.apiClient.baseURL.absoluteString)
                                .font(.footnote)
                                .foregroundStyle(ValorTheme.textSecondary)
                                .textSelection(.enabled)

                            Button {
                                Task { await appModel.checkHealth() }
                            } label: {
                                Text("Testar conexão")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(ValorTheme.accentGradient)
                                    .clipShape(Capsule())
                            }

                            if let status = appModel.statusMessage {
                                Text(status)
                                    .font(.footnote)
                                    .foregroundStyle(ValorTheme.textSecondary)
                            }
                        }
                    }

                    menuCard {
                        NavigationLink {
                            RemoveAdsSubscriptionScreen()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: appModel.removeAdsPurchased ? "checkmark.circle.fill" : "rectangle.slash")
                                    .font(.title2)
                                    .foregroundStyle(appModel.removeAdsPurchased ? ValorTheme.mintStrong : ValorTheme.purple)
                                    .frame(width: 36, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Remover anúncios")
                                        .font(.headline)
                                        .foregroundStyle(ValorTheme.textPrimary)
                                    Text(
                                        appModel.removeAdsPurchased
                                            ? "Sem anúncios ativos"
                                            : "R$ 19,90 / ano"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(ValorTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(ValorTheme.textSecondary.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    menuCard {
                        NavigationLink {
                            AboutScreen()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "heart.text.square.fill")
                                    .font(.title2)
                                    .foregroundStyle(ValorTheme.purple)
                                    .frame(width: 36, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sobre")
                                        .font(.headline)
                                        .foregroundStyle(ValorTheme.textPrimary)
                                    Text("Objetivo do app e equipe")
                                        .font(.caption)
                                        .foregroundStyle(ValorTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(ValorTheme.textSecondary.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    menuCard {
                        NavigationLink {
                            PrivacyPolicyScreen()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title2)
                                    .foregroundStyle(ValorTheme.purple)
                                    .frame(width: 36, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Políticas de Privacidade")
                                        .font(.headline)
                                        .foregroundStyle(ValorTheme.textPrimary)
                                    Text("Como tratamos os seus dados")
                                        .font(.caption)
                                        .foregroundStyle(ValorTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(ValorTheme.textSecondary.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    menuCard {
                        NavigationLink {
                            TermsOfUseScreen()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "doc.text.fill")
                                    .font(.title2)
                                    .foregroundStyle(ValorTheme.purple)
                                    .frame(width: 36, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Termos de Uso")
                                        .font(.headline)
                                        .foregroundStyle(ValorTheme.textPrimary)
                                    Text("Condições do serviço")
                                        .font(.caption)
                                        .foregroundStyle(ValorTheme.textSecondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(ValorTheme.textSecondary.opacity(0.75))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private func menuCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ValorTheme.cardSurfaceLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(ValorTheme.softPurple.opacity(0.38), lineWidth: 1)
            )
            .shadow(color: ValorTheme.purple.opacity(0.14), radius: 14, y: 8)
    }
}

/// Teclado numérico no estilo da barra inferior (não usa o teclado do sistema).
private struct ValorBarcodeKeypad: View {
    @Binding var text: String
    var onDone: () -> Void

    private let maxDigits = 32
    /// Só cantos superiores arredondados (como o teclado do sistema): evita “buracos” pretos nas quinas inferiores do painel.
    private let keypadCorner: CGFloat = 24
    private var keypadSurfaceShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: keypadCorner,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: keypadCorner,
            style: .continuous
        )
    }

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...9, id: \.self) { n in
                    digitKey("\(n)") {
                        appendDigit(String(n))
                    }
                }
                iconKey("delete.backward", role: .destructive) {
                    if !text.isEmpty { text.removeLast() }
                    haptic()
                }
                digitKey("0") {
                    appendDigit("0")
                }
                iconKey("checkmark.circle.fill", role: .accent) {
                    haptic()
                    onDone()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .background(keypadChrome)
        .clipShape(keypadSurfaceShape)
    }

    private var keypadChrome: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height) * 0.72

            ZStack {
                keypadSurfaceShape
                    .fill(ValorTheme.cardSurfaceLight)

                keypadSurfaceShape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.93),
                                Color.white.opacity(0.72),
                                Color.white.opacity(0.48),
                                Color.white.opacity(0.90)
                            ],
                            center: .center,
                            startRadius: r * 0.08,
                            endRadius: r
                        )
                    )

                keypadSurfaceShape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                ValorTheme.purple.opacity(0.04),
                                ValorTheme.purple.opacity(0.22),
                                ValorTheme.purple.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            }
            .compositingGroup()
        }
    }

    private enum IconRole {
        case normal
        case destructive
        case accent
    }

    private func digitKey(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            haptic()
            action()
        }) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(ValorTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: ValorTheme.purple.opacity(0.1), radius: 6, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ValorTheme.softPurple.opacity(0.38), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func iconKey(_ systemName: String, role: IconRole, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(iconForeground(role))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(iconBackground(role))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(ValorTheme.softPurple.opacity(role == .accent ? 0.25 : 0.38), lineWidth: 1)
                )
                .shadow(color: ValorTheme.purple.opacity(role == .accent ? 0.15 : 0.1), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func iconForeground(_ role: IconRole) -> some ShapeStyle {
        switch role {
        case .normal: ValorTheme.textPrimary
        case .destructive: Color.red.opacity(0.85)
        case .accent: Color.white
        }
    }

    @ViewBuilder
    private func iconBackground(_ role: IconRole) -> some View {
        switch role {
        case .normal, .destructive:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        case .accent:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ValorTheme.accentGradient)
        }
    }

    private func appendDigit(_ d: String) {
        guard text.count < maxDigits else { return }
        text.append(d)
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// Campo com teclado personalizado ValorCerto (substitui o teclado iOS).
private struct BarcodeKeypadField: UIViewRepresentable {
    @Binding var text: String
    var onEditingChanged: ((Bool) -> Void)?

    init(text: Binding<String>, onEditingChanged: ((Bool) -> Void)? = nil) {
        self._text = text
        self.onEditingChanged = onEditingChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onEditingChanged: onEditingChanged)
    }

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.spellCheckingType = .no
        tf.keyboardType = .numberPad
        tf.textContentType = .none
        tf.tintColor = UIColor(red: 0.58, green: 0.42, blue: 0.90, alpha: 1)
        tf.font = valorBarcodeTextFieldFont()
        tf.textColor = UIColor(red: 0.18, green: 0.16, blue: 0.28, alpha: 1)
        tf.delegate = context.coordinator
        tf.backgroundColor = .clear

        context.coordinator.textField = tf
        context.coordinator.rebuildKeypad()

        tf.inputView = context.coordinator.hosting?.view
        tf.text = text
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onEditingChanged = onEditingChanged
        uiView.font = valorBarcodeTextFieldFont()
        if uiView.text != text {
            uiView.text = text
        }
        uiView.inputView = context.coordinator.hosting?.view
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var onEditingChanged: ((Bool) -> Void)?
        weak var textField: UITextField?
        var hosting: UIHostingController<ValorBarcodeKeypad>?

        init(text: Binding<String>, onEditingChanged: ((Bool) -> Void)?) {
            self.text = text
            self.onEditingChanged = onEditingChanged
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged?(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            onEditingChanged?(false)
        }

        func rebuildKeypad() {
            guard let tf = textField else { return }
            let keypad = ValorBarcodeKeypad(
                text: Binding(
                    get: { self.text.wrappedValue },
                    set: { new in
                        let digits = new.filter { $0.isNumber }
                        let clipped = String(digits.prefix(32))
                        self.text.wrappedValue = clipped
                        tf.text = clipped
                    }
                ),
                onDone: { tf.resignFirstResponder() }
            )

            if let existing = hosting {
                existing.rootView = keypad
            } else {
                let hc = UIHostingController(rootView: keypad)
                // Transparente: as quinas fora do painel arredondado deixam ver o fundo da app (evita preto do contentView do sistema).
                hc.view.backgroundColor = .clear
                hc.view.isOpaque = false
                hc.view.clipsToBounds = true
                hc.view.layer.cornerRadius = 24
                hc.view.layer.cornerCurve = .continuous
                hc.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                let w = UIScreen.main.bounds.width
                hc.view.frame = CGRect(x: 0, y: 0, width: w, height: 300)
                hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                hosting = hc
            }
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if string.isEmpty { return true }
            return string.allSatisfy { $0.isNumber }
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScanned = onScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate,
    AVCaptureVideoDataOutputSampleBufferDelegate
{
    var onScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var didScan = false
    /// Oculto: só para `captureDevicePointConverted` no toque de foco (coordenadas iguais ao vídeo orientado).
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDevice: AVCaptureDevice?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    private let previewImageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.backgroundColor = .black
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let videoQueue = DispatchQueue(label: "com.valorcerto.scanner.video", qos: .userInitiated)
    private var shouldEmitPreviewFrames = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(previewImageView)
        NSLayoutConstraint.activate([
            previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: view.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        configureCapture()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFocusTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateVideoConnectionsOrientation()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateVideoConnectionsOrientation()
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        shouldEmitPreviewFrames = true
        if !session.isRunning {
            session.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateVideoConnectionsOrientation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        shouldEmitPreviewFrames = false
        if session.isRunning {
            session.stopRunning()
        }
    }

    /// Igual ao vídeo da pré-visualização do sistema para esta `UIWindowScene` (preview + samples + metadados).
    private func updateVideoConnectionsOrientation() {
        let avOrientation = Self.avCaptureOrientation(for: view.window?.windowScene)

        if let conn = previewLayer?.connection, conn.isVideoOrientationSupported {
            conn.videoOrientation = avOrientation
        }

        if let vo = videoDataOutput,
           let conn = vo.connection(with: .video),
           conn.isVideoOrientationSupported {
            conn.videoOrientation = avOrientation
        }

        for output in session.outputs {
            if let metaOut = output as? AVCaptureMetadataOutput,
               let conn = metaOut.connection(with: .metadata),
               conn.isVideoOrientationSupported {
                conn.videoOrientation = avOrientation
            }
        }
    }

    private static func avCaptureOrientation(for scene: UIWindowScene?) -> AVCaptureVideoOrientation {
        guard let scene else { return .portrait }
        switch scene.interfaceOrientation {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .unknown: return .portrait
        @unknown default: return .portrait
        }
    }

    private func configureCapture() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            return
        }

        videoDevice = videoCaptureDevice

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard session.canAddOutput(metadataOutput) else { return }
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [
            .ean8, .ean13, .upce, .code128, .qr
        ]

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { return }
        session.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoDataOutput = videoOutput

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        preview.isHidden = true
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        updateVideoConnectionsOrientation()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard shouldEmitPreviewFrames,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        let upright = orientedCIImage(ciImage, connection: connection)
        let grayscale = upright.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0])

        guard let cgImage = ciContext.createCGImage(grayscale, from: grayscale.extent) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldEmitPreviewFrames else { return }
            self.previewImageView.image = UIImage(cgImage: cgImage)
        }
    }

    /// Alinha o buffer ao mesmo `videoOrientation` da ligação (coerente com `AVCaptureVideoPreviewLayer`; câmara traseira).
    private func orientedCIImage(_ image: CIImage, connection: AVCaptureConnection) -> CIImage {
        let exif: CGImagePropertyOrientation
        switch connection.videoOrientation {
        case .portrait:
            exif = .right
        case .portraitUpsideDown:
            exif = .left
        case .landscapeRight:
            exif = .up
        case .landscapeLeft:
            exif = .down
        @unknown default:
            exif = .right
        }
        return image.oriented(forExifOrientation: Int32(exif.rawValue))
    }

    @objc private func handleFocusTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended,
              let device = videoDevice,
              let preview = previewLayer else { return }

        let pointInView = gesture.location(in: view)
        showFocusIndicator(at: pointInView)

        let devicePoint = preview.captureDevicePointConverted(fromLayerPoint: pointInView)

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }
            }
        } catch {
            // foco indisponível neste dispositivo/momento
        }
    }

    private func showFocusIndicator(at center: CGPoint) {
        let side: CGFloat = 72
        let indicator = UIView(frame: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side))
        indicator.layer.borderColor = UIColor.systemYellow.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 6
        indicator.layer.shadowColor = UIColor.black.cgColor
        indicator.layer.shadowOpacity = 0.35
        indicator.layer.shadowRadius = 5
        indicator.alpha = 1
        view.addSubview(indicator)

        UIView.animate(withDuration: 0.28, delay: 0.45, options: [.curveEaseOut]) {
            indicator.alpha = 0
            indicator.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        } completion: { _ in
            indicator.removeFromSuperview()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else {
            return
        }

        didScan = true
        session.stopRunning()
        onScanned?(stringValue)
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var history: [PriceCheckResponse] = []
    @Published var statusMessage: String?
    @Published var isLoading = false
    @Published var pendingBarcode: String?
    @Published var isScannerPresented = false
    /// Subscrição “sem anúncios”; também sincronizado com StoreKit quando possível.
    @Published private(set) var removeAdsPurchased = false
    /// Oculta o menu inferior (Sobre, legais, subscrição, etc.).
    @Published var suppressBottomMenuBar = false

    let apiClient = APIClient()

    private let removeAdsPurchasedKey = "valorcerto.remove_ads.purchased"

    /// Histórico só neste aparelho (JSON em Application Support). Migra dados antigos de UserDefaults.
    private let legacyHistoryStorageKey = "valorcerto.history.items.v3"
    private let historyFileName = "history-cache.json"

    init() {
        removeAdsPurchased = UserDefaults.standard.bool(forKey: removeAdsPurchasedKey)
        loadHistory()
        Task { await refreshRemoveAdsEntitlement() }
        Task { await listenForTransactionUpdates() }
    }

    func setRemoveAdsPurchased(_ value: Bool) {
        removeAdsPurchased = value
        UserDefaults.standard.set(value, forKey: removeAdsPurchasedKey)
    }

    func refreshRemoveAdsEntitlement() async {
        for await verificationResult in Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                if transaction.productID == ValorSubscriptionProductID.removeAdsAnnual {
                    setRemoveAdsPurchased(true)
                    return
                }
            case .unverified:
                continue
            }
        }
    }

    private func listenForTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            switch verificationResult {
            case .verified(let transaction):
                if transaction.productID == ValorSubscriptionProductID.removeAdsAnnual {
                    await transaction.finish()
                    setRemoveAdsPurchased(true)
                }
            case .unverified:
                continue
            }
        }
    }

    private func historyDirectoryURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ValorCerto", isDirectory: true)
    }

    private func historyFileURL() -> URL {
        historyDirectoryURL().appendingPathComponent(historyFileName)
    }

    func checkHealth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await apiClient.health()
            statusMessage = "Backend online"
        } catch {
            statusMessage = "Falha de conexão: \(error.localizedDescription)"
        }
    }

    func saveToHistory(_ result: PriceCheckResponse) {
        history.insert(result, at: 0)
        history = Array(history.prefix(40))
        persistHistory()
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        persistHistory()
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    func removeHistoryItem(id: String) {
        history.removeAll { $0.id == id }
        persistHistory()
    }

    private func loadHistory() {
        let fm = FileManager.default
        let dir = historyDirectoryURL()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let fileURL = historyFileURL()
        if fm.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PriceCheckResponse].self, from: data) {
            history = decoded
            return
        }

        if let data = UserDefaults.standard.data(forKey: legacyHistoryStorageKey),
           let decoded = try? JSONDecoder().decode([PriceCheckResponse].self, from: data) {
            history = decoded
            persistHistory()
            UserDefaults.standard.removeObject(forKey: legacyHistoryStorageKey)
        }
    }

    private func persistHistory() {
        try? FileManager.default.createDirectory(at: historyDirectoryURL(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? data.write(to: historyFileURL(), options: [.atomic])
    }
}

enum APIClientError: LocalizedError {
    case server(httpStatus: Int, message: String?)

    var userFacingMessage: String {
        switch self {
        case let .server(code, msg):
            if let msg, !msg.isEmpty {
                return msg
            }
            return "Servidor indisponível (código \(code)). Tenta de novo."
        }
    }
}

struct APIClient {
    let baseURL = URL(string: "https://valorcerto.netlify.app/api")!

    func health() async throws {
        _ = try await request(path: "health", method: "GET", body: Optional<Int>.none)
    }

    func priceCheck(barcode: String, userPrice: Double? = nil) async throws -> PriceCheckResponse {
        let body = PriceCheckRequest(barcode: barcode, user_price: userPrice)
        let data = try await request(path: "price-check", method: "POST", body: body)
        return try JSONDecoder().decode(PriceCheckResponse.self, from: data)
    }

    private struct ServerErrorPayload: Decodable {
        let error: String?
    }

    private func request<T: Encodable>(
        path: String,
        method: String,
        body: T?
    ) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let msg = try? JSONDecoder().decode(ServerErrorPayload.self, from: data).error
            throw APIClientError.server(httpStatus: httpResponse.statusCode, message: msg)
        }
        return data
    }
}

struct PriceCheckRequest: Encodable {
    let barcode: String
    let user_price: Double?

    enum CodingKeys: String, CodingKey {
        case barcode
        case user_price
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(barcode, forKey: .barcode)
        // Só envia user_price quando há valor — compatível com APIs que rejeitam `null` ou exigem número (>0).
        if let user_price {
            try c.encode(user_price, forKey: .user_price)
        }
    }
}

struct PriceCheckResponse: Codable, Identifiable {
    let compared: Bool
    let name: String
    let barcode: String
    let user_price: Double?
    let average_price: Double
    let status: String?
    let difference_percent: Int?

    enum CodingKeys: String, CodingKey {
        case compared
        case name
        case barcode
        case user_price
        case average_price
        case status
        case difference_percent
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compared = try c.decodeIfPresent(Bool.self, forKey: .compared) ?? false
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Produto"
        barcode = try c.decode(String.self, forKey: .barcode)
        user_price = try c.decodeIfPresent(Double.self, forKey: .user_price)
        average_price = try c.decode(Double.self, forKey: .average_price)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        difference_percent = try Self.decodeFlexibleInt(c, forKey: .difference_percent)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(compared, forKey: .compared)
        try c.encode(name, forKey: .name)
        try c.encode(barcode, forKey: .barcode)
        try c.encodeIfPresent(user_price, forKey: .user_price)
        try c.encode(average_price, forKey: .average_price)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(difference_percent, forKey: .difference_percent)
    }

    private static func decodeFlexibleInt(
        _ c: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Int? {
        if let i = try c.decodeIfPresent(Int.self, forKey: key) { return i }
        if let d = try c.decodeIfPresent(Double.self, forKey: key) { return Int(d.rounded()) }
        return nil
    }

    var id: String {
        let diff = difference_percent ?? 0
        return "\(barcode)_\(average_price)_\(name)_\(compared)_\(diff)"
    }

    var statusText: String {
        guard compared, let raw = status?.lowercased(), !raw.isEmpty else {
            return "Média de mercado"
        }
        switch raw {
        case "barato": return "Barato"
        case "ok": return "No preço"
        default: return "Caro"
        }
    }

    var statusIcon: String {
        guard compared, let raw = status?.lowercased(), !raw.isEmpty else {
            return "📊"
        }
        switch raw {
        case "barato": return "🟢"
        case "ok": return "🟡"
        default: return "🔴"
        }
    }

    var statusColor: Color {
        guard compared, let raw = status?.lowercased(), !raw.isEmpty else {
            return ValorTheme.purple
        }
        switch raw {
        case "barato": return .green
        case "ok": return .orange
        default: return .red
        }
    }
}

private extension Double {
    var currencyBRL: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: self)) ?? "R$ \(self)"
    }
}

#Preview {
    ContentView()
}
