export interface IConfigUI {
  [key: string] : string;
}

export interface IConfigNotif<T> {
  [key: string]: T;
}

export interface INotifStyle {
  colour: string;
  icon: string;
}

export const ConfigUI: IConfigUI = {
  // inventory: "",
  // paymentType: "",
  // acronym: "",
  // cryptoIcon: "",
  // estDeliveryTime: "",
}

export const ConfigNotif: IConfigNotif<INotifStyle> = {
  // success: {
  //   colour: "",
  //   icon: "",
  // },
  // error: {
  //   colour: "",
  //   icon: "",
  // }
}