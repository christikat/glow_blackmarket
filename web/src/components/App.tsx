import React, {useState, useEffect} from 'react';
import './App.css'
import {debugData} from "../utils/debugData";
import {fetchNui} from "../utils/fetchNui";
import { useNuiEvent } from '../hooks/useNuiEvent';
import { useVisibility } from '../providers/VisibilityProvider';
import Header from "./Header"
import Notif from './Notif';
import ShopItem from "./ShopItem"
import Cart from "./Cart"
import { Item, ICartItem, INotif } from '../types/interfaces';
import { ConfigUI, IConfigUI, ConfigNotif, IConfigNotif, INotifStyle } from '../config';

interface ClientData {
    marketItems: Item[];
    deliveryTime: number;
    currencyAmt: number;
}

// This will set the NUI to visible if we are
// developing in browser
debugData([
  {
    action: 'setVisible',
    data: true,
  }
])

const App: React.FC = () => {
    const { visible, setVisible } = useVisibility();
    const [notification, setNotification] = useState<INotif | null>(null);
    const [searchTerm, setSearchTerm] = useState("");
    const [cartItems, setCartItems] = useState<ICartItem[]>([]);
    const [marketItems, setMarketItems] = useState<Item[]>([]);
    const [playerCash, setPlayerCash] = useState(0);
    const [pendingOrder, setPendingOrder] = useState(false);
    const [epochTime, setEpochTime] = useState(0);

    useEffect(() => {
        fetchNui<{configData: IConfigUI, notifData: IConfigNotif<INotifStyle>}>("fetchConfig").then(data => {
            for (const [key, val] of Object.entries(data.configData)) ConfigUI[key] = val;
            for (const [key, val] of Object.entries(data.notifData)) ConfigNotif[key] = val;
        })
    }, [])

    useNuiEvent("notification", (data: {text: string, notifType: string}) => {
        setNotification({
            icon: <i className={ConfigNotif[data.notifType].icon}></i>,
            colour: ConfigNotif[data.notifType].colour,
            text: data.text,
        })
    })

    useNuiEvent("updateMarketItems", (data: Item[]) => {
        setMarketItems(data);
        if (cartItems.length > 0 && !pendingOrder) {
            setCartItems([]);
        }
    })

    useNuiEvent("loadPendingOrder", (data: {marketItems: Item[], order: {[key: string]: number}, epochTime: number}) => {
        setMarketItems(data.marketItems);
        setPendingOrder(true);
        const cart: ICartItem[] = data.marketItems.filter(marketItem => data.order[marketItem.item]).map(marketItem => ({...marketItem, quantity: data.order[marketItem.item]}));
        setCartItems(cart);
        setEpochTime(data.epochTime);
    })

    useNuiEvent("updateStock", (data: {items: Item[], notif: string, isOwner: boolean}) => {
        setMarketItems(data.items);
        // update cart for items that dont have enough stock
        if (!pendingOrder && !data.isOwner) {
            cartItems.forEach(cartItem => {
                if (typeof(cartItem.quantity) == "number") {
                    let shopItem = data.items.find(shopItem => shopItem.item === cartItem.item);
                    if (shopItem && cartItem.quantity > shopItem.stock) {
                        shopItem.stock == 0 ? removeFromCart(cartItem.item) : updateCartItemQuant(cartItem.item, shopItem.stock);
    
                        setNotification({
                            icon: <i className={ConfigNotif.error.icon}></i>,
                            colour: ConfigNotif.error.colour,
                            text: data.notif,
                        })
                    }
                }
            })
        }
    })

    useNuiEvent("clearOrder", () => {
        setCartItems([]);
        setPendingOrder(false);
        setEpochTime(0);
    })
    
    useEffect(() => {
        if (visible) {
            fetchNui<ClientData>("getClientData").then(data => {
                setMarketItems(data.marketItems);
                setPlayerCash(data.currencyAmt);
            }).catch(e => {
                console.error("Error fetching data", e)
            })
        }
    }, [visible])


    function handleSearch(e: React.ChangeEvent<HTMLInputElement>) {
        setSearchTerm(e.target.value);
    }

    const searchFilter = marketItems.filter((item) => 
        item.label.toLowerCase().includes(searchTerm.toLowerCase())
    );

    const itemEl = searchFilter.map((itemData) => {
        const cartItem = cartItems.find((cartItem) => cartItem.item === itemData.item);
        return (
            <ShopItem 
                key={itemData.item}
                item={itemData}
                disableAdd={pendingOrder || cartItem || itemData.stock == 0 ? true : false}
                addToCart={addToCart}
            />
        )
    })

    function addToCart(itemData: Item) {
        setCartItems((prevItems) => [...prevItems, {...itemData, quantity: 1}]);
    }

    function removeFromCart(item: string) {
        setCartItems(prevItems => {
            const newCartItems = prevItems.filter((cartItem) => {
                return cartItem.item !== item
            });
            return newCartItems
        })
    }

    function updateCartItemQuant(item: string, newQuant: number | "") {
        setCartItems(prevItems => {
            const index = prevItems.findIndex(obj => obj.item === item);
            const newArr = [...prevItems]; 
            newArr[index].quantity = newQuant;
            return newArr
        })
    }
    return (
    <div id="tablet" className={ConfigUI.tabletColour === "dark" ? "tablet-dark" : "tablet-light"}>
        <div id="camera" className={ConfigUI.tabletColour === "dark" ? "camera-dark" : "camera-light"}></div>
        <div id="tablet-screen">
            <Header
                icon={ConfigUI.paymentType === "crypto" ? <i className={ConfigUI.cryptoIcon}></i> : "$"}
                amt={playerCash}
                handleSearch={handleSearch}
            />
            {notification && <Notif notifyData={notification} onDismiss={() => setNotification(null)} />}
            <div id="main-container">
                <div id="items">{itemEl}</div>
                <Cart
                    pendingOrder = {pendingOrder}
                    cartItems={cartItems}
                    marketItems={marketItems}
                    epochTime={epochTime}
                    removeFromCart={removeFromCart}
                    updateCartItemQuant={updateCartItemQuant}
                    setPendingOrder={setPendingOrder}
                />
            </div>
        </div>
        <div id="home"></div>
    </div>
  );
}

export default App;