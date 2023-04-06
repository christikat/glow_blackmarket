import { Item } from '../types/interfaces';
import { ConfigUI } from '../config';

interface ShopItemProps {
  item: Item;
  disableAdd: boolean;
  addToCart: (item: Item) => void;
}

const ShopItem = ({item, disableAdd, addToCart}: ShopItemProps) => {
  function handleAddCart() {
    addToCart(item)
  }

  return(<div className="item-container">
      <div className="item-name">{item.label}</div>
      <img src={`https://cfx-nui-${ConfigUI.inventory}/html/images/${item.image}`} />
      <div className="item-price">{ConfigUI.paymentType === "crypto" ? `${item.price} ${ConfigUI.acronym}` : `$${item.price}`}</div>
      <div className="item-stock">Stock: {item.stock}</div>
      <button onClick={handleAddCart} disabled={disableAdd} className="item-add">Add To Cart</button>
  </div>)
}

export default ShopItem