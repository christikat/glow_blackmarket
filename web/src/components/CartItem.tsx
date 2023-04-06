import { ICartItem, Item } from '../types/interfaces';
import { useState } from 'react';
import { ConfigUI } from '../config';


interface CartItemProps {
    itemData: ICartItem;
    shopItemStock: number;
    removeFromCart: (item: string) => void;
    updateCartItemQuant: (item: string, quant: number | "") => void;
}

const CartItem = ({itemData, shopItemStock, removeFromCart, updateCartItemQuant}: CartItemProps) => {
    const [animateClass, setAnimateClass] = useState<string>("animate__fadeInLeft");
    const totalItemPrice = typeof(itemData.quantity) == "number" ? itemData.price*itemData.quantity : 0;
    
    function handleRemoveFromCart() {
        setAnimateClass("animate__fadeOutLeft");
    }

    function handleAnimationEnd(e: React.AnimationEvent<HTMLInputElement>) {
        if (e.animationName === "fadeOutLeft") {
            removeFromCart(itemData.item);
        }
    }

    function handleInputChange(e: React.ChangeEvent<HTMLInputElement>) {
        const quant = e.target.value != "" ? parseInt(e.target.value): "";
        updateCartItemQuant(itemData.item, quant);
    }

    function handleInputBlur(e: React.ChangeEvent<HTMLInputElement>) {
        const quant = parseInt(e.target.value);
        if (e.target.value === "" || quant < 1) {
            updateCartItemQuant(itemData.item, 1);
            return
        }
        
        if (quant > shopItemStock) {
            updateCartItemQuant(itemData.item, shopItemStock);
            return
        }
        
        updateCartItemQuant(itemData.item, quant)
    }

    function handleDecrease() {
        if (typeof(itemData.quantity) == "number" && itemData.quantity > 1) {
            updateCartItemQuant(itemData.item, itemData.quantity - 1);
        }
    }

    function handleIncrease() {
        if (typeof(itemData.quantity) == "number" && itemData.quantity < shopItemStock) {
            updateCartItemQuant(itemData.item, itemData.quantity + 1);
        }
    }

    return (
        <div onAnimationEnd={handleAnimationEnd} className={`checkout-item-container animate__animated ${animateClass} animate__faster`}>
            <div className="checkout-item-left">
                <div className="checkout-item">{itemData.label}</div>  
                <button onClick={handleRemoveFromCart} className="checkout-remove">Remove</button>
            </div>
            <div className="checkout-item-right">
                <div className="checkout-amt">
                    <div onClick={handleDecrease} className="checkout-decrease checkout-increment">-</div>
                    <input 
                        onBlur={handleInputBlur}
                        onChange={handleInputChange}
                        type="number"
                        value={itemData.quantity}
                        className="checkout-input"
                    />
                    <div onClick={handleIncrease} className="checkout-increase checkout-increment">+</div>
                </div>
                <div className="checkout-price">{ConfigUI.paymentType === "crypto" ? `${totalItemPrice} ${ConfigUI.acronym}` : `$${totalItemPrice}`}</div>
            </div>
        </div>
    )
}

export default CartItem