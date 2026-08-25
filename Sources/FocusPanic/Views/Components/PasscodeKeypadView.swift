import AppKit
import SwiftUI

public struct PasscodeKeypadView: View {
    @Binding var pin: String
    var maxDigits: Int
    var title: String
    var subtitle: String
    var tintColor: Color
    var showKeypad: Bool
    var isSuccess: Bool
    var errorMessage: String?
    var onComplete: ((String) -> Void)?
    
    @State private var showPlain = false
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    public init(
        pin: Binding<String>,
        maxDigits: Int = 4,
        title: String = "",
        subtitle: String = "",
        tintColor: Color = Color(hex: "#E11D48"),
        showKeypad: Bool = true,
        isSuccess: Bool = false,
        errorMessage: String? = nil,
        onComplete: ((String) -> Void)? = nil
    ) {
        self._pin = pin
        self.maxDigits = max(4, maxDigits)
        self.title = title
        self.subtitle = subtitle
        self.tintColor = tintColor
        self.showKeypad = showKeypad
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            if !title.isEmpty {
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            
            // Cajas Visuales de PIN (Sin fugas de cursor rojo)
            ZStack {
                // Entrada de teclado completamente oculta
                TextField("", text: $pin)
                    .focused($isInputFocused)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .clipped()
                    .allowsHitTesting(false)
                    .onChange(of: pin) { newVal in
                        if newVal.count > maxDigits {
                            pin = String(newVal.prefix(maxDigits))
                        }
                        if pin.count == maxDigits {
                            onComplete?(pin)
                        }
                    }
                
                HStack(spacing: 12) {
                    ForEach(0..<maxDigits, id: \.self) { index in
                        let hasChar = index < pin.count
                        let charString = hasChar ? String(pin[pin.index(pin.startIndex, offsetBy: index)]) : ""
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.08))
                                .frame(width: 46, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            hasChar
                                                ? (isSuccess ? Color.green : tintColor)
                                                : (index == pin.count ? Color.accentColor : Color.secondary.opacity(0.2)),
                                            lineWidth: hasChar ? 2 : 1
                                        )
                                )
                                .shadow(color: hasChar ? (isSuccess ? Color.green.opacity(0.3) : tintColor.opacity(0.3)) : Color.clear, radius: 5, x: 0, y: 2)
                            
                            if hasChar {
                                if showPlain {
                                    Text(charString)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                } else {
                                    Circle()
                                        .fill(isSuccess ? Color.green : tintColor)
                                        .frame(width: 14, height: 14)
                                }
                            } else if index == pin.count {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(width: 2, height: 18)
                                    .opacity(0.8)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isInputFocused = true
                        }
                    }
                }
            }
            .offset(x: shakeOffset)
            
            if let error = errorMessage, !error.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundColor(.red)
                .transition(.opacity)
            }
            
            // Teclado Numérico en Pantalla
            if showKeypad {
                VStack(spacing: 8) {
                    ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { digit in
                                keyButton(title: "\(digit)") {
                                    appendDigit("\(digit)")
                                }
                            }
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { showPlain.toggle() }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.06))
                                    .frame(width: 58, height: 40)
                                Image(systemName: showPlain ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Ver contraseña")
                        
                        keyButton(title: "0") {
                            appendDigit("0")
                        }
                        
                        Button(action: { deleteDigit() }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.06))
                                    .frame(width: 58, height: 40)
                                Image(systemName: "delete.left.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Borrar último dígito")
                    }
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isInputFocused = true
            }
        }
    }
    
    private func keyButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 58, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    )
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func appendDigit(_ digit: String) {
        if pin.count < maxDigits {
            NSSound(named: "Tink")?.play()
            pin += digit
            if pin.count == maxDigits {
                onComplete?(pin)
            }
        }
    }
    
    private func deleteDigit() {
        if !pin.isEmpty {
            pin.removeLast()
        }
    }
    
    public func triggerShake() {
        NSSound(named: "Basso")?.play()
        withAnimation(.default) { shakeOffset = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { withAnimation(.default) { shakeOffset = 10 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { withAnimation(.default) { shakeOffset = -6 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { withAnimation(.default) { shakeOffset = 6 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { withAnimation(.default) { shakeOffset = 0 } }
    }
}
