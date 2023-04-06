import {fetchNui} from "../utils/fetchNui";

interface HeaderProps {
    icon: JSX.Element | string;
    amt: number;
    handleSearch: (event: React.ChangeEvent<HTMLInputElement>) => void;
}

const Header = ({icon, amt, handleSearch}: HeaderProps) => {

  function handleClose() {
    fetchNui("close");
  }

  return (
    <div id="top">
        <input onChange={handleSearch} id="search" type="text" placeholder="Search" />
        <div id="crypto" className="top-item">
            <div className="crypto-icon">{icon}</div>
            <div className="currency-amt">{amt}</div>
        </div>
        <div onClick={handleClose} id="close" className="top-item">
            <i className="fa-solid fa-x"></i>
        </div>
    </div>
  )
}

export default Header