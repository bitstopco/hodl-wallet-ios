//
//  ReceiveViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let qrSize: CGFloat = 186.0
private let smallButtonHeight: CGFloat = 32.0
private let buttonPadding: CGFloat = 5.0
private let smallSharePadding: CGFloat = 12.0
private let largeSharePadding: CGFloat = 20.0

typealias PresentShare = (String, UIImage) -> Void

class ReceiveViewController : UIViewController, Subscriber, Trackable {

    //MARK - Public
    var presentEmail: PresentShare?
    var presentText: PresentShare?

    init(wallet: BRWallet, store: Store, isRequestAmountVisible: Bool) {
        self.wallet = wallet
        self.isRequestAmountVisible = isRequestAmountVisible
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    //MARK - Private
    private let qrCode = UIImageView()
    private let address = UILabel(font: .customBody(size: 14.0))
    private let addressPopout = InViewAlert(type: .primary)
    private let share = ShadowButton(title: S.Receive.share, type: .tertiary, image: #imageLiteral(resourceName: "Share"), imageColor: .gradientStart, backColor: .black)
    private let sharePopout = InViewAlert(type: .secondary)
    private let border = UIView()
    private let request = ShadowButton(title: S.Receive.request, type: .secondary)
    private let addressButton = UIButton(type: .system)
    private var topSharePopoutConstraint: NSLayoutConstraint?
    private let wallet: BRWallet
    private let store: Store
    private var balance: UInt64? = nil {
        didSet {
            if let newValue = balance, let oldValue = oldValue {
                if newValue > oldValue {
                    setReceiveAddress()
                }
            }
        }
    }
    fileprivate let isRequestAmountVisible: Bool
    private var requestTop: NSLayoutConstraint?
    private var requestBottom: NSLayoutConstraint?

    override func viewDidLoad() {
        addSubviews()
        addConstraints()
        setStyle()
        addActions()
        setupCopiedMessage()
        setupShareButtons()
        store.subscribe(self, selector: { $0.walletState.balance != $1.walletState.balance }, callback: {
            self.balance = $0.walletState.balance
        })
    }

    private func addSubviews() {
        view.addSubview(qrCode)
        view.addSubview(address)
        view.addSubview(addressPopout)
        view.addSubview(share)
        view.addSubview(sharePopout)
        view.addSubview(border)
        view.addSubview(request)
        view.addSubview(addressButton)
    }

    private func addConstraints() {
        qrCode.constrain([
            qrCode.constraint(.width, constant: qrSize),
            qrCode.constraint(.height, constant: qrSize),
            qrCode.constraint(.top, toView: view, constant: C.padding[12]),
            qrCode.constraint(.centerX, toView: view) ])
        address.constrain([
            address.constraint(toBottom: qrCode, constant: C.padding[1]),
            address.constraint(.centerX, toView: view) ])
        addressPopout.heightConstraint = addressPopout.constraint(.height, constant: 0.0)
        addressPopout.constrain([
            addressPopout.constraint(toBottom: address, constant: 0.0),
            addressPopout.constraint(.centerX, toView: view),
            addressPopout.constraint(.width, toView: view),
            addressPopout.heightConstraint ])
        share.constrain([
            share.constraint(toTop: sharePopout, constant: 0.0),
            share.constraint(.leading, toView: view, constant: 0.0),
            share.constraint(.trailing, toView: view, constant: 0.0),
            share.constraint(.height, constant: 65.0), ])
        sharePopout.heightConstraint = sharePopout.constraint(.height, constant: 0.0)
        topSharePopoutConstraint = sharePopout.constraint(toBottom: share, constant: largeSharePadding)
        sharePopout.constrain([
            topSharePopoutConstraint,
            sharePopout.constraint(.centerX, toView: view),
            sharePopout.constraint(.width, toView: view),
            sharePopout.constraint(toTop: request, constant: 0.0),
            sharePopout.heightConstraint ])
        border.constrain([
            border.constraint(.width, toView: view),
            border.constraint(toTop: request, constant: 0.0),
            border.constraint(.centerX, toView: view),
            border.constraint(.height, constant: 2.0) ])
        requestBottom = request.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0.0)
        request.constrain([
            request.constraint(.leading, toView: view, constant: 0.0),
            request.constraint(.trailing, toView: view, constant: 0.0),
            request.constraint(.height, constant: 65.0),
            requestBottom ])
        addressButton.constrain([
            addressButton.leadingAnchor.constraint(equalTo: address.leadingAnchor, constant: -C.padding[1]),
            addressButton.topAnchor.constraint(equalTo: qrCode.topAnchor),
            addressButton.trailingAnchor.constraint(equalTo: address.trailingAnchor, constant: C.padding[1]),
            addressButton.bottomAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[1]) ])
    }

    private func setStyle() {
        view.backgroundColor = .grayBackground
        address.textColor = .whiteTint
        border.backgroundColor = .grayBackground
        share.tintColor = .black
        share.isToggleable = true
        sharePopout.clipsToBounds = true
        sharePopout.backgroundColor = .black
        addressButton.setBackgroundImage(UIImage.imageForColor(.secondaryGrayText), for: .highlighted)
        addressButton.layer.cornerRadius = 4.0
        addressButton.layer.masksToBounds = true
        setReceiveAddress()
    }

    private func setReceiveAddress() {
        address.text = wallet.receiveAddress
        qrCode.image = UIImage.qrCode(data: "\(address.text!)".data(using: .utf8)!, color: CIColor(color: .whiteTint))?
            .resize(CGSize(width: qrSize, height: qrSize))!
    }

    private func addActions() {
        addressButton.tap = { [weak self] in
            self?.addressTapped()
        }
        request.tap = { [weak self] in
            guard let modalTransitionDelegate = self?.parent?.transitioningDelegate as? ModalTransitionDelegate else { return }
            modalTransitionDelegate.reset()
            self?.dismiss(animated: true, completion: {
                self?.store.perform(action: RootModalActions.Present(modal: .requestAmount))
            })
        }
        share.addTarget(self, action: #selector(ReceiveViewController.shareTapped), for: .touchUpInside)
    }

    private func setupCopiedMessage() {
        let copiedMessage = UILabel(font: .customMedium(size: 14.0))
        copiedMessage.textColor = .white
        copiedMessage.text = S.Receive.copied
        copiedMessage.textAlignment = .center
        addressPopout.contentView = copiedMessage
    }

    private func setupShareButtons() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let email = ShadowButton(title: S.Receive.emailButton, type: .tertiary, image: #imageLiteral(resourceName: "Email"), imageColor: .gradientStart, backColor: .grayBackground)
        let text = ShadowButton(title: S.Receive.textButton, type: .tertiary, image: #imageLiteral(resourceName: "Text"), imageColor: .gradientStart, backColor: .grayBackground)
        let or = UILabel(font: .customBody(size: 16.0), color: .whiteTint)
        container.addSubview(email)
        container.addSubview(text)
        container.addSubview(or)
        email.constrain([
            email.constraint(.leading, toView: container),
            email.constraint(.top, toView: container, constant: buttonPadding),
            email.constraint(.bottom, toView: container, constant: -buttonPadding),
            email.trailingAnchor.constraint(equalTo: container.centerXAnchor, constant: -C.padding[2]) ])
        or.constrain([
            or.constraint(.centerX, toView: container),
            or.constraint(.centerY, toView: container) ])
        text.constrain([
            text.constraint(.trailing, toView: container),
            text.constraint(.top, toView: container, constant: buttonPadding),
            text.constraint(.bottom, toView: container, constant: -buttonPadding),
            text.leadingAnchor.constraint(equalTo: container.centerXAnchor, constant: C.padding[2]) ])
        sharePopout.contentView = container
        or.text = S.Receive.orLabel
        email.addTarget(self, action: #selector(ReceiveViewController.emailTapped), for: .touchUpInside)
        text.addTarget(self, action: #selector(ReceiveViewController.textTapped), for: .touchUpInside)
    }

    @objc private func shareTapped() {
        toggle(alertView: sharePopout, shouldAdjustPadding: true)
        if addressPopout.isExpanded {
            toggle(alertView: addressPopout, shouldAdjustPadding: false)
        }
    }

    @objc private func addressTapped() {
        guard let text = address.text else { return }
        saveEvent("receive.copiedAddress")
        UIPasteboard.general.string = text
        toggle(alertView: addressPopout, shouldAdjustPadding: false, shouldShrinkAfter: true)
        if sharePopout.isExpanded {
            toggle(alertView: sharePopout, shouldAdjustPadding: true)
        }
    }

    @objc private func emailTapped() {
        presentEmail?(address.text!, qrCode.image!)
    }

    @objc private func textTapped() {
        presentText?(address.text!, qrCode.image!)
    }

    private func toggle(alertView: InViewAlert, shouldAdjustPadding: Bool, shouldShrinkAfter: Bool = false) {
        share.isEnabled = false
        address.isUserInteractionEnabled = false

        var deltaY = alertView.isExpanded ? -alertView.height : alertView.height
        if shouldAdjustPadding {
            if deltaY > 0 {
                deltaY -= (largeSharePadding - smallSharePadding)
            } else {
                deltaY += (largeSharePadding - smallSharePadding)
            }
        }

        if alertView.isExpanded {
            alertView.contentView?.isHidden = true
        }

        UIView.spring(C.animationDuration, animations: {
            if shouldAdjustPadding {
                let newPadding = self.sharePopout.isExpanded ? largeSharePadding : smallSharePadding
                self.topSharePopoutConstraint?.constant = newPadding
            }
            alertView.toggle()
            self.parent?.view.layoutIfNeeded()
        }, completion: { _ in
            alertView.isExpanded = !alertView.isExpanded
            self.share.isEnabled = true
            self.address.isUserInteractionEnabled = true
            alertView.contentView?.isHidden = false
            if shouldShrinkAfter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                    if alertView.isExpanded {
                        self.toggle(alertView: alertView, shouldAdjustPadding: shouldAdjustPadding)
                    }
                })
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ReceiveViewController : ModalDisplayable {
    var faqArticleId: String? {
        return ArticleIds.receiveBitcoin
    }

    var modalTitle: String {
        return S.Receive.title
    }
}
