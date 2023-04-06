import { ConfigUI } from '../config';

interface OrderItemProps {
    quantity: number;
    label: string;
    price: number;
}

const OrderItem = ({quantity, label, price}: OrderItemProps) => {
    return (
        <div className="order-item-container">
            <div className="order-left">
                <div className="order-item-amt">{quantity}x</div>
                <div className="order-item">{label}</div>
            </div>
            <div className="order-item-price">{ConfigUI.paymentType === "crypto" ? `${price * quantity} ${ConfigUI.acronym}` : `$${price * quantity}`}</div>
        </div>
    )
}
export default OrderItem