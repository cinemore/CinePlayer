//
//  SiderContanierView.swift
//  Cinemore
//

import SwiftUI

/// 弹出方向枚举
enum ContainerDirection {
    case trailing // 从右侧弹出
    case bottom // 从底部弹出
}

struct SiderContanierView<Content: View>: View {
    /// 是否显示容器
    var show: Bool
    /// 几何信息
    var geometry: GeometryProxy
    /// 弹出方向
    var direction: ContainerDirection
    /// 容器宽度，只在从右侧弹出时使用
    var width: CGFloat?
    /// 背景
    var showBackground = true

    @ViewBuilder
    var content: Content

    private var offset: CGSize {
        switch direction {
        case .trailing:
            CGSize(width: show ? 0 : geometry.size.width, height: 0)
        case .bottom:
            CGSize(width: 0, height: show ? 0 : geometry.size.height)
        }
    }

    private var alignment: Alignment {
        switch direction {
        case .trailing:
            .topTrailing
        case .bottom:
            .bottom
        }
    }

    private var cornerRadius: CGFloat {
        PlatformServices.displayCornerRadius()
    }

    private let trailingOuterInset: CGFloat = 8
    private let bottomOuterInset: CGFloat = 8

    private var leadingCornerRadius: CGFloat {
        #if canImport(UIKit)
            return 24
        #else
            return 16
        #endif
    }

    private var interceptTransparentArea: Bool {
        direction == .trailing
    }

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: direction == .trailing ? (width ?? 380) : .infinity)
                .if(direction == .trailing) {
                    $0.frame(maxHeight: .infinity, alignment: .top)
                }
                .background {
                    if interceptTransparentArea {
                        Rectangle()
                            .fill(Color.black.opacity(show ? 0.001 : 0))
                            .contentShape(Rectangle())
                            .allowsHitTesting(show)
                            .onTapGesture {}
                    }
                }
                .if(interceptTransparentArea) {
                    $0.contentShape(Rectangle())
                }
                .if(showBackground) {
                    if direction == .trailing {
                        // 从右边弹出，右边两个角使用屏幕圆角
                        $0.modifier(GlassEffectModifier(
                            topLeading: leadingCornerRadius,
                            topTrailing: cornerRadius,
                            bottomLeading: leadingCornerRadius,
                            bottomTrailing: cornerRadius,
                            material: .regularMaterial,
                            useCapsule: false,
                            clipsContent: true
                        ))
                    } else {
                        // 从底部弹出，下面两个角使用屏幕圆角
                        $0.modifier(GlassEffectModifier(
                            topLeading: leadingCornerRadius,
                            topTrailing: leadingCornerRadius,
                            bottomLeading: cornerRadius,
                            bottomTrailing: cornerRadius,
                            material: .regularMaterial,
                            useCapsule: false,
                            clipsContent: true
                        ))
                    }
                }
                .offset(x: offset.width, y: offset.height)
                .allowsHitTesting(show)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: show)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: alignment
        )
        .if(direction == .trailing) {
            $0.padding(.top, trailingOuterInset)
                .padding(.trailing, trailingOuterInset)
                .padding(.bottom, trailingOuterInset)
        }
        .if(direction == .bottom) {
            $0.padding(.vertical, bottomOuterInset)
                .padding(.horizontal, bottomOuterInset)
        }
        .ignoresSafeArea(.all)
    }
}
