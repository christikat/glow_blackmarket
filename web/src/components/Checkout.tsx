import { useEffect, useState } from 'react';
import { ConfigUI } from '../config';
import { useNuiEvent } from '../hooks/useNuiEvent';
import { fetchNui } from '../utils/fetchNui';
import { ICartItem } from '../types/interfaces';



interface CheckoutProps {
    total: number;
    items: ICartItem[];
    pendingOrder: boolean;
    epochTime: number;
    setPendingOrder: (state: boolean) => void;
}

const Checkout = ({total, items, pendingOrder, epochTime, setPendingOrder} : CheckoutProps) => {
    const [formatedTime, setFormatedTime] = useState("");
    const [orderReady, setOrderReady] = useState(false);

    function formatTime(epoch: number) {
        const deliveryTime = new Date(epoch * 1000);
        const formatedDeliveryTime = deliveryTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: 'numeric', hour12: true });
        setFormatedTime(formatedDeliveryTime);
    }
    
    function handleCheckout() {
        fetchNui<{success: boolean, epochTime: number | null}>("submitOrder", items).then(data => {
            if (data.success) {
                setPendingOrder(true);
                if (data.epochTime) {
                    formatTime(data.epochTime);
                }
            }
        }).catch(e => {
            console.error("Failed to submit order", e)
        })
    }

    useEffect(() => {
        epochTime > 0 ? formatTime(epochTime) : setFormatedTime("");
    }, [epochTime])
    
    useNuiEvent("orderReady", () => setOrderReady(true));

    function handleLocation() {
        if (orderReady) {
            fetchNui("deliveryLocation");
        }
    }

    return (
        <div id="checkout-bottom">
            <div id="checkout-delivery-time">
                <div id="checkout-total-text">{pendingOrder && formatedTime != "" ? "Delivery Time" : "Est. Delivery"}</div>
                <div id="checkout-total-amt">{pendingOrder && formatedTime != "" ? formatedTime : ConfigUI.estDeliveryTime + " Mins"}</div>
            </div>
            <div id="checkout-total">
                <div id="checkout-total-text">Total</div>
                <div id="checkout-total-amt">{ConfigUI.paymentType === "crypto" ? `${total} ${ConfigUI.acronym}` : `$${total}`}</div>
            </div>
            {
                pendingOrder ?
                <div onClick={handleLocation} id="order-location" className={`side-button ${orderReady || "disable-button"}`}>Locate Drop Off</div> :
                <div onClick={handleCheckout} id="checkout-button" className="side-button">Checkout</div>
            }
        </div>
      )
}

export default Checkout