export interface Item {
    item: string;
    price: number;
    label: string;
    stock: number;
    image: string;
}

export interface ICartItem extends Item {
    quantity: number | "";
}

export interface INotif {
    text: string;
    colour: string;
    icon: React.ReactNode;
}