import CartItem from "./CartItem"
import Checkout from './Checkout'
import { ICartItem, Item } from '../types/interfaces';
import OrderItem from "./OrderItem";

interface CartProps {
    pendingOrder: boolean;
    marketItems: Item[];
    cartItems: ICartItem[];
    epochTime: number;
    removeFromCart: (item: string) => void;
    updateCartItemQuant: (item: string, quant: number | "") => void;
    setPendingOrder: (state: boolean) => void;
}
  

const Cart = ({cartItems, marketItems, pendingOrder, epochTime, removeFromCart, updateCartItemQuant, setPendingOrder}: CartProps) => {
    const totalPrice = cartItems.reduce((total:number, item:ICartItem) => {
        const quantity = typeof(item.quantity) === "number" ? item.quantity : 0;
        return total + item.price * quantity
    }, 0);
       
    const cartItemsEl = cartItems.map((item: ICartItem) => {
        const shopItem = marketItems.find(shopItem => shopItem.item === item.item);
        const shopStock = shopItem ? shopItem.stock : 0
        return pendingOrder ? (
            <OrderItem 
                key={item.item}
                quantity={typeof(item.quantity) === "number" ? item.quantity : 1}
                label={item.label}
                price={item.price}
            />
        ) : (<CartItem 
            key={item.item}
            itemData={item}
            shopItemStock={shopStock}
            removeFromCart={removeFromCart}
            updateCartItemQuant={updateCartItemQuant}
        />)
    })

    return (
        <div id="checkout">
            <div className="checkout-header">{pendingOrder ? "Pending Order" : "Shopping Cart"}</div>
            <div id="checkout-items">
                {cartItems.length == 0 ? <div id="checkout-empty">Your cart is empty</div> : cartItemsEl}
            </div>

            {cartItems.length > 0 &&
                <Checkout
                    total={totalPrice}
                    items={cartItems}
                    pendingOrder={pendingOrder}
                    epochTime={epochTime}
                    setPendingOrder={setPendingOrder}
                />}
        </div>
    )
}

export default Cart